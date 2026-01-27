module Search
  class GoodsNomenclatureIndex < ::SearchIndex
    INDEX_NAME = 'goods_nomenclatures'.freeze

    def name
      [TradeTariffBackend::SearchClient.server_namespace, INDEX_NAME, TradeTariffBackend.service].join('-')
    end

    def definition
      {
        mappings: {
          properties: {
            # Presentational fields
            goods_nomenclature_sid: { type: 'long' },
            goods_nomenclature_item_id: { type: 'keyword' },
            producline_suffix: { type: 'keyword' },
            chapter_short_code: { type: 'keyword' },
            heading_short_code: { type: 'keyword' },
            number_indents: { type: 'integer' },
            declarable: { type: 'boolean' },
            goods_nomenclature_class: { type: 'keyword' },
            formatted_description: { type: 'keyword', index: false },
            validity_start_date: { type: 'date', format: 'date_optional_time' },
            validity_end_date: { type: 'date', format: 'date_optional_time' },

            # Searchable fields
            description: { type: 'text', analyzer: 'snowball' },
            ancestor_descriptions: { type: 'text', analyzer: 'snowball' },
            search_references: {
              type: 'text',
              analyzer: 'snowball',
            },
            labels: {
              properties: {
                description: { type: 'text', analyzer: 'snowball' },
                known_brands: { type: 'text', analyzer: 'snowball' },
                colloquial_terms: { type: 'text', analyzer: 'snowball' },
                synonyms: { type: 'text', analyzer: 'snowball' },
              },
            },
          },
        },
      }
    end

    def model_class
      GoodsNomenclature
    end

    def eager_load
      [
        :goods_nomenclature_indents,
        :goods_nomenclature_descriptions,
        :goods_nomenclature_label,
        :search_references,
        { ancestors: [:goods_nomenclature_descriptions] },
      ]
    end

    def dataset_page(page_number)
      TimeMachine.now do
        dataset
          .actual
          .with_leaf_column
          .eager(eager_load)
          .paginate(page_number, page_size)
          .all
      end
    end

    def total_pages
      TimeMachine.now do
        (dataset.with_leaf_column.count / page_size.to_f).ceil
      end
    end
  end
end
