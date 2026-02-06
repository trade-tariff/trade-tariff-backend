module Search
  class SearchSuggestionQuery
    attr_reader :query_string, :date, :allowed_types, :size

    def initialize(query_string, date, allowed_types: nil, size: 10)
      @query_string = query_string
      @date = date
      @allowed_types = allowed_types
      @size = size
    end

    def query
      {
        index: Search::SearchSuggestionsIndex.new.name,
        body: {
          size: size,
          query: {
            bool: {
              must: [match_clause],
              filter: type_filter,
              should: [
                exact_match_clause, # Exact matches boosted highest
                wildcard_clause, # Prefix matches boosted moderately
              ],
            },
          },
          collapse: { field: 'value.keyword' },
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

    # Boosts documents whose value exactly matches the query string (case-insensitive).
    # This ensures 100% character matches always rank first.
    def exact_match_clause
      {
        term: {
          'value.keyword': {
            value: query_string,
            boost: 100,
            case_insensitive: true,
          },
        },
      }
    end

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

    # Restricts results to allowed suggestion types when specified.
    # Returns an empty array (no filter) when all types are allowed.
    def type_filter
      return [] if allowed_types.blank?

      [{ terms: { suggestion_type: allowed_types } }]
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
