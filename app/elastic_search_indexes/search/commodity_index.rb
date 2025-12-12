module Search
  class CommodityIndex < ::SearchIndex
    def goods_nomenclature?
      true
    end

    def definition
      {
        mappings: {
          properties: {
            id: { type: 'long' },
            description: { type: 'text', analyzer: 'snowball' },
            description_indexed: { type: 'text', analyzer: 'snowball' },
            goods_nomenclature_item_id: { type: 'keyword' },
            declarable: { enabled: false },
            ancestor_descriptions: { enabled: false },
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
            validity_end_date: { format: 'date_optional_time', type: 'date' },
            number_indents: { type: 'long' },
            validity_start_date: { type: 'date', format: 'date_optional_time' },
            producline_suffix: { type: 'keyword' },
            section: {
              dynamic: true,
              properties: {
                position: { type: 'long' },
                title: { type: 'text' },
                numeral: { type: 'keyword' },
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
      }
    end

    def dataset_page(page_number)
      TimeMachine.now do
        super(page_number)
      end
    end

    def eager_load
      [{
        goods_nomenclature_indents: [],
        goods_nomenclature_descriptions: [],
        heading: %i[goods_nomenclature_indents goods_nomenclature_descriptions],
        chapter: %i[goods_nomenclature_descriptions guides sections],
      },
       ancestors: {goods_nomenclature_descriptions:[]},
       descendants: { },
      ]
    end
  end
end
