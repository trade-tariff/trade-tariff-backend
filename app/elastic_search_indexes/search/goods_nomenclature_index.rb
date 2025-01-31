module Search
  class GoodsNomenclatureIndex
    def name
      [TradeTariffBackend::SearchClient.server_namespace, 'goods_nomenclatures', TradeTariffBackend.service].join('-')
    end

    def definition
      {
        mappings: {
          properties: {
            id: { type: 'long' },
            description: { type: 'text', analyzer: 'ngram_analyzer', search_analyzer: 'lowercase_analyzer' },
            goods_nomenclature_item_id: { type: 'text', analyzer: 'ngram_analyzer', search_analyzer: 'lowercase_analyzer' },
            declarable: { enabled: false },
            validity_start_date: { type: 'date', format: 'date_optional_time' },
            validity_end_date: { format: 'date_optional_time', type: 'date' },
            number_indents: { type: 'long' },
            producline_suffix: { type: 'keyword' },
            type: { type: 'keyword' },
            search_references: {
              "properties": {
                title: { type: 'text', analyzer: 'ngram_analyzer', search_analyzer: 'lowercase_analyzer' },
                reference_class: { type: 'keyword' },
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
                max_gram: 20,
              },
            },
            analyzer: {
              ngram_analyzer: {
                type: 'custom',
                tokenizer: 'standard',
                filter: %w[lowercase ngram_filter],
              },
              lowercase_analyzer: {
                type: 'custom',
                tokenizer: 'standard',
                filter: %w[lowercase],
              },
            },
          },
        },
      }
    end

    def total_pages
      # TODO: revisit for build_index
      0
    end
  end
end
