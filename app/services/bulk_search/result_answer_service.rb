module BulkSearch
  class ResultAnswerService
    MAX_ANCESTORS = 5

    def initialize(search, hits, number_of_digits: 6)
      @search = search
      @hits = hits || []
      @number_of_digits = number_of_digits
    end

    def call
      search_results = hits.each_with_object({}) do |hit, acc|
        candidate_ancestor, reason = HitAncestorFinderService.new(hit, number_of_digits).call

        next if candidate_ancestor.blank?

        acc[candidate_ancestor.short_code] ||= {
          ancestor: BulkSearch::SearchResult.build(candidate_ancestor),
          accumulated_score: 0,
          reason:,
        }
        acc[candidate_ancestor.short_code][:accumulated_score] += hit._score
      end

      sort_and_accumulate_search_results(search_results)
    end

    private

    attr_reader :search, :hits, :number_of_digits

    def sort_and_accumulate_search_results(search_results)
      return search.search_results.concat(fallback_ancestors) if search_results.blank?

      sorted = search_results.sort_by { |_short_code, ancestor|
        ancestor[:accumulated_score]
      }.reverse.first(MAX_ANCESTORS)

      sorted.each do |_short_code, ancestor|
        ancestor[:ancestor].score = ancestor[:accumulated_score]
        ancestor[:ancestor].reason = ancestor[:reason]

        search.search_results << ancestor[:ancestor]
      end
    end

    def fallback_ancestors
      [
        BulkSearch::SearchResult.build(
          short_code: '999999',
          reason: :no_search_result,
        ),
      ]
    end
  end
end
