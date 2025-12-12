module Search
  class SearchReferenceIndex < SearchIndex
    def definition
      {
        mappings: {
          properties: {
            title: { type: 'text', analyzer: 'snowball' },
            title_indexed: { type: 'text', analyzer: 'snowball' },
            reference_class: { type: 'keyword' },
            reference: {
              properties: {
                position: { type: 'long' },
                numeral: { type: 'keyword' },
                validity_end_date: { type: 'date', format: 'date_optional_time' },
                class: { type: 'keyword' },
                validity_start_date: { type: 'date', format: 'date_optional_time' },
                goods_nomenclature_item_id: { type: 'keyword' },
                section: {
                  dynamic: true,
                  properties: {
                    position: { type: 'long' },
                    title: { type: 'text' },
                    numeral: { type: 'keyword' },
                  },
                },
                id: { type: 'long' },
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
                title: { type: 'text' },
                description: { type: 'text' },
                number_indents: { type: 'long' },
                producline_suffix: { type: 'keyword' },
                heading: {
                  dynamic: true,
                  properties: {
                    number_indents: { type: 'long' },
                    description: { type: 'text' },
                    validity_start_date: { type: 'date', format: 'date_optional_time' },
                    producline_suffix: { type: 'keyword' },
                    goods_nomenclature_sid: { type: 'long' },
                    goods_nomenclature_item_id: { type: 'keyword' },
                  },
                },
              },
              type: 'nested',
            },
          },
        },
      }
    end

    def dataset_page(page_number)
      TimeMachine.now do
        super(page_number)
      end
    end

    def eager_load
      {
        referenced: {
          goods_nomenclature_indents: [],
          goods_nomenclature_descriptions: [],
          heading: %i[goods_nomenclature_indents goods_nomenclature_descriptions],
          chapter: %i[guides sections goods_nomenclature_descriptions],
        }
      }
    end
  end
end
