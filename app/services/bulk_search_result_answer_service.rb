class BulkSearchResultAnswerService
  HEADING_DIGITS = 4
  MAX_ANCESTORS = 5

  def initialize(search, hits, ancestor_digits: 6)
    @search = search
    @hits = hits
    @ancestor_digits = ancestor_digits
  end

  def call
    search_result_ancestors = hits.each_with_object({}) do |hit, acc|
      candidate_ancestor, reason = find_result_in_ancestor(hit)

      if candidate_ancestor.blank?
        candidate_ancestor, reason = find_result_in_hit(hit)
      end

      if candidate_ancestor.blank?
        candidate_ancestor, reason = find_result_in_heading_ancestor(hit)
      end

      next if candidate_ancestor.blank?

      acc[candidate_ancestor.short_code] ||= {
        ancestor: BulkSearch::SearchAncestor.build(candidate_ancestor),
        accumulated_score: 0,
        reason:,
      }
      acc[candidate_ancestor.short_code][:accumulated_score] += hit['_score']
    end

    sort_and_accumulate_search_result_ancestors(search_result_ancestors)
  end

  private

  attr_reader :search, :hits, :ancestor_digits

  def sort_and_accumulate_search_result_ancestors(search_result_ancestors)
    return search.search_result_ancestors.concat(fallback_ancestors) if search_result_ancestors.blank?

    sorted = search_result_ancestors.sort_by { |_short_code, ancestor|
      ancestor[:accumulated_score]
    }.reverse.first(MAX_ANCESTORS)

    sorted.each do |_short_code, ancestor|
      ancestor[:ancestor].score = ancestor[:accumulated_score]
      ancestor[:ancestor].reason = ancestor[:reason]

      search.search_result_ancestors << ancestor[:ancestor]
    end
  end

  def find_result_in_ancestor(hit)
    result = hit._source.ancestors.find do |ancestor|
      ancestor.short_code.length == ancestor_digits
    end

    reason = :matching_digit_ancestor if result

    [result, reason]
  end

  def find_result_in_hit(hit)
    hit_digits = hit._source.short_code.length

    result = [ancestor_digits, HEADING_DIGITS].include?(hit_digits) ? hit._source : nil

    reason = if result.present?
               result.goods_nomenclature_class == 'Heading' ? :matching_declarable_heading : :matching_digit_commodity
             end

    [result, reason]
  end

  def find_result_in_heading_ancestor(hit)
    result = hit._source.ancestors.find do |ancestor|
      ancestor.short_code.length == HEADING_DIGITS
    end

    reason = :matching_heading_ancestor if result

    [result, reason]
  end

  def fallback_ancestors
    [
      BulkSearch::SearchAncestor.build(
        short_code: '999999',
        reason: :no_search_result,
      ),
    ]
  end
end
