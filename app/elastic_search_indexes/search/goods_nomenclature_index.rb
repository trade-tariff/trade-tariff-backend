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
                  # TODO: When the synonym files are ready to be deployed on AWS ES we will uncomment this
                  # filter: %w[
                  #   synonym
                  #   english_possessive_stemmer
                  #   lowercase
                  #   english_stop
                  #   english_stemmer
                  # ],
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
                # TODO: When the synonym files are ready to be deployed on AWS ES we will uncomment this
                # synonym: {
                #   type: 'synonym',
                #   synonyms_path: '/usr/share/opensearch/config/synonyms_generic.txt',
                # },
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
            id: { type: 'text' },
            goods_nomenclature_class: { type: 'keyword' },
            goods_nomenclature_item_id: { type: 'text' },
            producline_suffix: { type: 'keyword' },
            search_references: { analyzer: 'english', type: 'text' },
            description_indexed: { analyzer: 'english', type: 'text' },
            ancestor_1_description_indexed: { analyzer: 'english', type: 'text' },
            ancestor_2_description_indexed: { analyzer: 'english', type: 'text' },
            ancestor_3_description_indexed: { analyzer: 'english', type: 'text' },
            ancestor_4_description_indexed: { analyzer: 'english', type: 'text' },
            ancestor_5_description_indexed: { analyzer: 'english', type: 'text' },
            ancestor_6_description_indexed: { analyzer: 'english', type: 'text' },
            ancestor_7_description_indexed: { analyzer: 'english', type: 'text' },
            ancestor_8_description_indexed: { analyzer: 'english', type: 'text' },
            ancestor_9_description_indexed: { analyzer: 'english', type: 'text' },
            ancestor_10_description_indexed: { analyzer: 'english', type: 'text' },
            ancestor_11_description_indexed: { analyzer: 'english', type: 'text' },
            ancestor_12_description_indexed: { analyzer: 'english', type: 'text' },
            ancestor_13_description_indexed: { analyzer: 'english', type: 'text' },
            description: { enabled: false },
            ancestors: { enabled: false },
            ancestor_ids: { enabled: false },
            validity_start_date: { enabled: false },
            validity_end_date: { enabled: false },
            heading_id: { enabled: false },
            chapter_id: { enabled: false },
          },
        },
      }
    end
  end
end
