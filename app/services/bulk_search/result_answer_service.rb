module BulkSearch
  class ResultAnswerService
    MAX_ANCESTORS = 5

    def initialize(search, hits, ancestor_digits: 6)
      @search = search
      @hits = hits || []
      @ancestor_digits = ancestor_digits
    end

    def call
      search_result_ancestors = hits.each_with_object({}) do |hit, acc|
        candidate_ancestor, reason = HitAncestorFinderService.new(hit, ancestor_digits).call

        next if candidate_ancestor.blank?

        acc[candidate_ancestor.short_code] ||= {
          ancestor: BulkSearch::SearchAncestor.build(candidate_ancestor),
          accumulated_score: 0,
          reason:,
        }
        acc[candidate_ancestor.short_code][:accumulated_score] += hit._score
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

    def fallback_ancestors
      [
        BulkSearch::SearchAncestor.build(
          short_code: '999999',
          reason: :no_search_result,
        ),
      ]
    end
  end
end
