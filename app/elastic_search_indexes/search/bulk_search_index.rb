module Search
  class BulkSearchIndex < ::SearchIndex
    include PointInTimeIndex

    def dataset_heading(heading_short_code)
      declarables = GoodsNomenclature
        .actual
        .where(heading_short_code:)
        .declarable
        .eager(*eager_load)
        .all

      [
        BulkSearchDocumentBuilderService.new(declarables, 6).call,
        BulkSearchDocumentBuilderService.new(declarables, 8).call,
      ].flatten.compact
    end

    def eager_load
      [
        :goods_nomenclature_descriptions,
        :search_references,
        :tradeset_descriptions,
        :children,
        { ancestors: %i[search_references goods_nomenclature_descriptions] },
      ]
    end

    def definition
      if TradeTariffBackend.stemming_exclusion_reference_analyzer.present?
        # Stemming exclusions _must_ come before other filters
        base_definition[:settings][:index][:analysis][:analyzer][:english][:filter].unshift('english_stem_exclusions')
        base_definition[:settings][:index][:analysis][:filter][:english_stem_exclusions] = {
          type: 'stemmer_override',
          rules_path: TradeTariffBackend.stemming_exclusion_reference_analyzer,
        }
      end

      if TradeTariffBackend.synonym_reference_analyzer.present?
        # Synonyms _must_ come before the stemming exclusion filter otherwise
        # they will have a mixture of stemmed/unstemmed expanded terms
        base_definition[:settings][:index][:analysis][:analyzer][:english][:filter].unshift('synonym')
        base_definition[:settings][:index][:analysis][:filter][:synonym] = {
          type: 'synonym',
          synonyms_path: TradeTariffBackend.synonym_reference_analyzer,
        }
      end

      base_definition
    end

    def base_definition
      @base_definition ||= {
        settings: {
          index: {
            analysis: {
              analyzer: {
                english: {
                  tokenizer: 'standard',
                  filter: %w[
                    english_possessive_stemmer
                    lowercase
                    english_stop
                    english_stemmer
                  ],
                },
              },
              filter: {
                english_stop: {
                  type: 'stop',
                  stopwords: '_english_',
                },
                english_stemmer: {
                  type: 'stemmer',
                  language: 'english',
                },
                english_possessive_stemmer: {
                  type: 'stemmer',
                  language: 'possessive_english',
                },
              },
              char_filter: {
                standardise_quotes: {
                  type: 'mapping',
                  mappings: [
                    '\\u0091=>\\u0027',
                    '\\u0092=>\\u0027',
                    '\\u2018=>\\u0027',
                    '\\u2019=>\\u0027',
                    '\\u201B=>\\u0027',
                  ],
                },
              },
            },
          },
        },
        mappings: {
          properties: {
            number_of_digits: {
              type: 'keyword',
            },
            indexed_descriptions: {
              type: 'text',
              analyzer: 'english',
            },
            indexed_tradeset_descriptions: {
              type: 'text',
              analyzer: 'english',
            },
            intercept_terms: {
              type: 'text',
              analyzer: 'english',
            },
            search_references: {
              type: 'text',
              analyzer: 'english',
            },
            short_code: {
              enabled: false,
            },
          },
        },
      }
    end
  end
end
