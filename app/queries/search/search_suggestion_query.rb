module Search
  class SearchSuggestionQuery
    attr_reader :query_string, :date

    def initialize(query_string, date)
      @query_string = query_string
      @date = date
    end

    def query
      {
        index: Search::SearchSuggestionsIndex.new.name,
        body: {
          query: {
            bool: {
              should: [
                wildcard_clause,
                match_clause,
              ],
              minimum_should_match: 1,
            },
          },
          sort: [
            { _score: { order: 'desc' } },
            { priority: { order: 'asc' } },
          ],
        },
      }
    end

    private

    def wildcard_clause
      {
        wildcard: {
          'value.keyword': {
            value: "#{query_string}*",
            boost: 20,
          },
        },
      }
    end

    def match_clause
      {
        match: {
          value: {
            query: query_string,
            fuzziness: 'AUTO',
            operator: 'or',
          },
        },
      }
    end
  end
end
