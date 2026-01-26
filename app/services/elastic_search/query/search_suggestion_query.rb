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
                should: wildcard_clauses,
                must: [
                  hidden_goods_nomenclature_filter,
                  multi_match_clause,
                  validity_date_filter,
                ],
              },
            },
            highlight: {
              fields: {
                '*': {},
              },
            },
          },
        }
      end

      private

      def wildcard_clauses
        clauses = [
          wildcard_clause('goods_nomenclature_item_id.keyword'),
          wildcard_clause('search_references.title.keyword'),
          wildcard_clause('chemicals.cus.keyword'),
          wildcard_clause('chemicals.cas_rn.keyword'),
          wildcard_clause('chemicals.name.keyword'),
        ]

        if SearchLabels.enabled?
          clauses += [
            wildcard_clause('labels.known_brands.keyword'),
            wildcard_clause('labels.colloquial_terms.keyword'),
            wildcard_clause('labels.synonyms.keyword'),
          ]
        end

        clauses
      end

      def wildcard_clause(field)
        {
          wildcard: {
            field => {
              value: "#{query_string} *",
              boost: 20,
            },
          },
        }
      end

      def multi_match_clause
        {
          multi_match: {
            query: query_string,
            fields: multi_match_fields,
            type: 'best_fields',
            fuzziness: 'AUTO',
            operator: 'or',
          },
        }
      end

      def multi_match_fields
        fields = %w[
          goods_nomenclature_item_id^5
          chemicals.cus^0.5
          chemicals.cas_rn^0.5
          search_references.title
          chemicals.name^0.1
        ]

        if SearchLabels.enabled?
          fields += %w[
            labels.description^0.5
            labels.known_brands^2
            labels.colloquial_terms^2
            labels.synonyms^1.5
          ]
        end

        fields
      end

      def hidden_goods_nomenclature_filter
        {
          bool: {
            must_not: {
              terms: {
                goods_nomenclature_item_id: HiddenGoodsNomenclature.codes,
              },
            },
          },
        }
      end

      def validity_date_filter
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
        }
      end
    end
  end
end
