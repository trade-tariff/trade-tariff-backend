class AncestorSearchResultService
  HEADING_DIGITS = 4
  MAX_ANCESTORS = 5

  def initialize(search, hits, ancestor_digits: 6)
    @search = search
    @hits = hits
    @ancestor_digits = ancestor_digits
  end

  def call
    search_result_ancestors = hits.each_with_object({}) do |hit, acc|
      reason = :no_matching_digit_ancestor

      # Find the ancestor with the same number of digits as the ancestor digits
      candidate_ancestor = hit._source.ancestors.find do |ancestor|
        ancestor.short_code.length == ancestor_digits
      end

      reason = :matching_digit_ancestor if candidate_ancestor.present?

      # Check if the hit is already the ancestor we're targeting or a declarable
      # heading
      candidate_ancestor ||= begin
        hit_digits = hit._source.short_code.length
        found = [ancestor_digits, HEADING_DIGITS].include?(hit_digits) ? hit._source : nil

        if found.present?
          reason = :matching_declarable_heading if found.goods_nomenclature_class == 'Heading'
          reason = :matching_digit_commodity if found.goods_nomenclature_class == 'Commodity'
        end

        found
      end

      # Otherwise check if the hit has a 4 digit ancestor
      candidate_ancestor ||= begin
        found = hit._source.ancestors.find do |ancestor|
          ancestor.short_code.length == 4
        end

        reason = :matching_heading_ancestor if found

        found
      end

      if candidate_ancestor.present?
        acc[candidate_ancestor.short_code] ||= {
          ancestor: BulkSearch::SearchAncestor.build(candidate_ancestor),
          accumulated_score: 0,
          reason:,
        }

        acc[candidate_ancestor.short_code][:accumulated_score] += hit['_score']
      elsif hit._source.short_code.length == ancestor_digits
        acc[hit.short_code] ||= {
          ancestor: BulkSearch::SearchAncestor.build(hit),
          accumulated_score: hit['_score'],
        }
      end
    end

    if search_result_ancestors.present?
      search_result_ancestors = search_result_ancestors.sort_by { |_short_code, ancestor|
        ancestor[:accumulated_score]
      }.reverse.first(MAX_ANCESTORS)

      search_result_ancestors.each do |_short_code, ancestor|
        ancestor[:ancestor].score = ancestor[:accumulated_score]
        ancestor[:ancestor].reason = ancestor[:reason]

        search.search_result_ancestors << ancestor[:ancestor]
      end
    else
      search.search_result_ancestors.concat(fallback_ancestors)
    end
  end

  private

  attr_reader :search, :hits, :ancestor_digits

  def fallback_ancestors
    [
      BulkSearch::SearchAncestor.build(
        short_code: '999999',
        reason: :no_search_result,
      ),
    ]
  end
end
