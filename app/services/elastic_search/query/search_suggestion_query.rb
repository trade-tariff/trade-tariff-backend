module ElasticSearch
  module Query
    class SearchSuggestionQuery
      INDEX_SIZE_MAX = 10_000 # ElasticSearch does default pagination for 10 entries
      # per page. We do not do pagination when displaying
      # results so have a constant much bigger than possible
      # index size for size value.

      attr_reader :query_string,
                  :date,
                  :index

      def initialize(query_string, date, index)
        @query_string = query_string
        @date = date
        @index = index
      end

      def query
        {
          index: index.name,
          body: {
            query: {
              bool: {
                "should": [
                  {
                    "wildcard": {
                      "goods_nomenclature_item_id.keyword": {
                        "value": "*#{query_string}*",
                        "boost": 20,
                      },
                    },
                  },
                  {
                    "wildcard": {
                      "search_references.title.keyword": {
                        "value": "*#{query_string}*",
                        "boost": 20,
                      },
                    },
                  },
                  {
                    "wildcard": {
                      "chemicals.cus.keyword": {
                        "value": "*#{query_string}*",
                        "boost": 20,
                      },
                    },
                  },
                  {
                    "wildcard": {
                      "chemicals.cas_rn.keyword": {
                        "value": "*#{query_string}*",
                        "boost": 20,
                      },
                    },
                  },
                  {
                    "wildcard": {
                      "chemicals.name.keyword": {
                        "value": "*#{query_string}*",
                        "boost": 20,
                      },
                    },
                  },
                ],
                must: [
                  {
                    bool: {
                      must_not: {
                        terms: {
                          goods_nomenclature_item_id: HiddenGoodsNomenclature.codes,
                        },
                      },
                    },
                  },
                  {
                    multi_match: {
                      query: query_string,
                      fields: %w[goods_nomenclature_item_id search_references.title chemicals.cus chemicals.cas_rn chemicals.name],
                      type: 'best_fields',
                      fuzziness: 'AUTO',
                      operator: 'or',
                    },
                  },
                  {
                    bool: {
                      should: [
                        # actual date is either between item's (validity_start_date..validity_end_date)
                        {
                          bool: {
                            must: [
                              { range: { validity_start_date: { lte: date } } },
                              { range: { validity_end_date: { gte: date } } },
                            ],
                          },
                        },
                        # or is greater than item's validity_start_date
                        # and item has blank validity_end_date (is unbounded)
                        {
                          bool: {
                            must: [
                              { range: { validity_start_date: { lte: date } } },
                              { bool: { must_not: { exists: { field: 'validity_end_date' } } } },
                            ],
                          },
                        },
                        # or item has blank validity_start_date and validity_end_date
                        {
                          bool: {
                            must: [
                              { bool: { must_not: { exists: { field: 'validity_start_date' } } } },
                              { bool: { must_not: { exists: { field: 'validity_end_date' } } } },
                            ],
                          },
                        },
                      ],
                    },
                  },
                ],
              },
            },
            "highlight": {
              "fields": {
                "*": {},
              },
            },
          },
        }
      end
    end
  end
end
