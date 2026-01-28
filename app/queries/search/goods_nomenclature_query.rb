module Search
  class GoodsNomenclatureQuery
    DEFAULT_SIZE = 30

    attr_reader :query_string, :date

    def initialize(query_string, date)
      @query_string = query_string
      @date = date
    end

    def query
      {
        index: index.name,
        body: {
          query: {
            bool: {
              must: [
                hidden_goods_nomenclature_filter,
                multi_match_clause,
                validity_date_filter,
              ],
            },
          },
          size: DEFAULT_SIZE,
        },
      }
    end

    private

    def index
      @index ||= GoodsNomenclatureIndex.new
    end

    def multi_match_clause
      {
        multi_match: {
          query: query_string,
          fields: search_fields,
          type: 'best_fields',
          operator: 'and',
        },
      }
    end

    def search_fields
      fields = %w[
        search_references^5
        description^3
        ancestor_descriptions
      ]

      if SearchLabels.enabled?
        fields += %w[
          labels.known_brands^2
          labels.colloquial_terms^2
          labels.synonyms^1.5
          labels.description
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
            {
              bool: {
                must: [
                  { range: { validity_start_date: { lte: date } } },
                  { range: { validity_end_date: { gte: date } } },
                ],
              },
            },
            {
              bool: {
                must: [
                  { range: { validity_start_date: { lte: date } } },
                  { bool: { must_not: { exists: { field: 'validity_end_date' } } } },
                ],
              },
            },
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
