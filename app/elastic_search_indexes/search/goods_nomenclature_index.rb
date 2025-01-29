module Search
  class GoodsNomenclatureIndex

    def self.name
      [TradeTariffBackend::SearchClient.server_namespace, 'goods_nomenclatures', TradeTariffBackend.service].join('-')
    end

    def definition
      {
        mappings: {
          properties: {
            dynamic: false,
            id: { type: 'long' },
            description: { type: 'text', analyzer: 'ngram_analyzer', search_analyzer: 'lowercase_analyzer' },
            goods_nomenclature_item_id: { type: 'keyword', analyzer: 'ngram_analyzer', search_analyzer: 'lowercase_analyzer' },
            declarable: { enabled: false },
            validity_end_date: { format: 'date_optional_time', type: 'date' },
            number_indents: { type: 'long' },
            validity_start_date: { type: 'date', format: 'date_optional_time' },
            producline_suffix: { type: 'keyword' },
            search_references: {
              "type": 'nested',
              "properties": {
                title: { type: 'text', analyzer: 'ngram_analyzer', search_analyzer: 'lowercase_analyzer' },
                reference_class: { type: 'keyword' },
              },
            },
            section: {
              dynamic: true,
              properties: {
                position: { type: 'long' },
                title: { type: 'text' },
                numeral: { type: 'keyword' },
              },
            },
            chapter: {
              dynamic: true,
              properties: {
                description: { type: 'text' },
                validity_start_date: { type: 'date', format: 'date_optional_time' },
                producline_suffix: { type: 'keyword' },
                goods_nomenclature_sid: { type: 'long' },
                goods_nomenclature_item_id: { type: 'keyword' },
              },
            },
            heading: {
              dynamic: true,
              properties: {
                validity_end_date: { type: 'date', format: 'date_optional_time' },
                number_indents: { type: 'long' },
                description: { type: 'text' },
                validity_start_date: { type: 'date', format: 'date_optional_time' },
                producline_suffix: { type: 'keyword' },
                goods_nomenclature_sid: { type: 'long' },
                goods_nomenclature_item_id: { type: 'keyword' },
              },
            },
          },
        },
        settings: {
          analysis: {
            filter: {
              ngram_filter: {
                type: 'edge_ngram',
                min_gram: 2,
                max_gram: 20
              }
            },
            analyzer: {
              ngram_analyzer: {
                type: 'custom',
                tokenizer: 'standard',
                filter: %w[lowercase ngram_filter]
              },
              lowercase_analyzer: {
                type: 'custom',
                tokenizer: 'standard',
                filter: %w[lowercase]
              }
            }
          }
        }
      }
    end

    def eager_load
      {
        goods_nomenclature_indents: [],
        goods_nomenclature_descriptions: [],
        heading: %i[goods_nomenclature_indents goods_nomenclature_descriptions],
        chapter: %i[goods_nomenclature_descriptions guides sections],
      }
    end
  end
end
