module Search
  class GoodsNomenclatureIndex < ::SearchIndex
    def dataset
      TimeMachine.now do
        GoodsNomenclature.actual
      end
    end

    def eager_load_graph
      %i[
        goods_nomenclature_indents
        chapter
        heading
        ancestors
      ]
    end

    def definition
      {
        settings: {
          index: {
            analysis: {
              analyzer: {
                english_exact: {
                  tokenizer: 'standard',
                  filter: %w[lowercase],
                },
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
            goods_nomenclature_class: {
              analyzer: 'english',
              type: 'text',
              fields: {
                raw: {
                  type: 'keyword',
                },
              },
            },
            goods_nomenclature_item_id: {
              type: 'text',
              fields: {
                raw: {
                  type: 'keyword',
                },
              },
            },
            producline_suffix: {
              type: 'text',
              fields: {
                raw: {
                  type: 'keyword',
                },
              },
            },
            description: {
              analyzer: 'english',
              type: 'text',
              fields: {
                exact: {
                  type: 'text',
                  analyzer: 'english_exact',
                },
              },
            },
            description_indexed: {
              analyzer: 'english',
              type: 'text',
            },
            chapter_description: {
              analyzer: 'english',
              type: 'text',
            },
            heading_description: {
              type: 'text',
              analyzer: 'english',
            },
            search_references: {
              analyzer: 'english',
              type: 'text',
            },
            ancestors: {
              type: 'nested',
              properties: {
                goods_nomenclature_item_id: { type: 'text' },
                producline_suffix: { type: 'text' },
                class: { type: 'text' },
                description: { type: 'text' },
              },
            },
            validity_start_date: {
              type: 'text',
            },
            validity_end_date: {
              type: 'text',
            },
            heading_id: {
              type: 'text',
              analyzer: 'english',
            },
            chapter_id: {
              type: 'text',
              analyzer: 'english',
            },
          },
        },
      }
    end
  end
end
