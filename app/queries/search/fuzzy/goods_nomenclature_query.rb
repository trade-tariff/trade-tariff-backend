module Search
  module Fuzzy
    class GoodsNomenclatureQuery < Query
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
                  {
                    multi_match: {
                      query: query_string,
                      operator: 'and',
                      fields: query_opts[:fields].presence || %w[description_indexed],
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
            size: INDEX_SIZE_MAX,
          },
        }
      end
    end
  end
end
