class SearchService
  class FuzzySearch < BaseSearch
    class GoodsNomenclatureQuery < FuzzyQuery
      def query(query_opts = {})
        {
          index: index.name,
          search: {
            query: {
              bool: {
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
                  multi_match_part(query_opts),
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
            size: INDEX_SIZE_MAX,
          },
        }
      end

      def multi_match_part(query_opts = {})
        query = {
          # match the search phrase
          multi_match: {
            query: query_string,
            operator: 'and',
          }.merge(query_opts),
        }

        query[:multi_match][:fields] = if search_through_negated_ancestors?
                                         %w[description_indexed]
                                       else
                                         %w[description]
                                       end

        query
      end

      def search_through_negated_ancestors?
        TradeTariffBackend.legacy_search_ancestors_enabled?
      end
    end
  end
end
