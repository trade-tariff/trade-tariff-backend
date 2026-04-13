require 'digest/md5'

module Search
  class SearchSuggestionsIndex < ::SearchIndex
    INDEX_NAME = 'search_suggestions'.freeze

    def name
      [TradeTariffBackend::SearchClient.server_namespace, INDEX_NAME, TradeTariffBackend.service].join('-')
    end

    def model_class
      SearchSuggestion
    end

    def document_id(model)
      "#{model.id}:#{Digest::MD5.hexdigest(model.value.to_s)}"
    end

    def definition
      {
        mappings: {
          properties: {
            value: {
              type: 'text',
              fields: {
                keyword: {
                  type: 'keyword',
                  ignore_above: 256,
                },
              },
              analyzer: 'ngram_analyzer',
              search_analyzer: 'lowercase_analyzer',
            },
            suggestion_type: { type: 'keyword' },
            priority: { type: 'integer' },
            goods_nomenclature_sid: { type: 'long' },
            goods_nomenclature_class: { type: 'keyword' },
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
  end
end
