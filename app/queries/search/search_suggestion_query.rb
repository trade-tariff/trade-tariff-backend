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
              must: [match_clause],
              should: [wildcard_clause],
            },
          },
          # Best matches first, then by priority (chapter > heading > commodity)
          # as a tiebreaker.
          sort: [
            { _score: { order: 'desc' } },
            { priority: { order: 'asc' } },
          ],
        },
      }
    end

    private

    # Boosts documents whose value starts with the exact query string.
    # Optional — only affects ranking, not inclusion.
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

    # Requires documents to match the search term against the ngram-analyzed
    # value field with fuzzy matching. This is a relevance gate and documents that don't match are excluded entirely.
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
