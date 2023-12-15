class SearchService
  class FuzzySearch < BaseSearch
    class ReferenceQuery < FuzzyQuery
      def query(*)
        {
          index: SearchReference.elasticsearch_index.name,
          search: {
            query: {
              bool: {
                must: multi_match_part,
                filter: {
                  bool: {
                    must: [
                      { term: { reference_class: index.type.capitalize } },
                      {
                        nested: {
                          path: 'reference',
                          query: {
                            bool: {
                              must: { match_all: {} },
                              filter: {
                                bool: {
                                  should: [
                                    # actual date is either between item's (validity_start_date..validity_end_date)
                                    {
                                      bool: {
                                        must: [
                                          { range: { 'reference.validity_start_date' => { lte: date } } },
                                          { range: { 'reference.validity_end_date' => { gte: date } } },
                                        ],
                                      },
                                    },
                                    # or is greater than item's validity_start_date
                                    # and item has blank validity_end_date (is unbounded)
                                    {
                                      bool: {
                                        must: [
                                          { range: { 'reference.validity_start_date' => { lte: date } } },
                                          { bool: { must_not: { exists: { field: 'reference.validity_end_date' } } } },
                                        ],
                                      },
                                    },
                                    # or item has blank validity_start_date and validity_end_date
                                    {
                                      bool: {
                                        must: [
                                          { bool: { must_not: { exists: { field: 'reference.validity_start_date' } } } },
                                          { bool: { must_not: { exists: { field: 'reference.validity_end_date' } } } },
                                        ],
                                      },
                                    },
                                  ],
                                },
                              },
                            },
                          },
                        },
                      },
                    ],
                  },
                },
              },
            },
            size: INDEX_SIZE_MAX,
          },
        }
      end

      def multi_match_part
        query = {
          multi_match: {
            query: query_string,
            operator: 'and',
          },
        }

        query[:multi_match][:fields] = if search_through_negated_title?
                                         %w[title_indexed]
                                       else
                                         %w[title]
                                       end

        query
      end

      def search_through_negated_title?
        TradeTariffBackend.legacy_search_ancestors_enabled? &&
          SearchNegationService::NEGATION_TERMS.none? { |term| query_string.include?(term) }
      end
    end
  end
end
