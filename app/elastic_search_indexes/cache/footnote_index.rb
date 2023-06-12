module Cache
  class FootnoteIndex < ::Cache::CacheIndex
    def definition
      {
        mappings: {
          dynamic: false,
          properties: {
            footnote_id: { type: 'keyword' },
            footnote_type_id: { type: 'keyword' },
            description: { type: 'text', analyzer: 'snowball' },
            validity_start_date: { type: 'date', format: 'date_optional_time' },
            validity_end_date: { type: 'date', format: 'date_optional_time' },
          },
        },
      }
    end

    def eager_load
      {
        footnote_descriptions: {},
        goods_nomenclatures: %i[goods_nomenclature_descriptions
                                ns_children
                                goods_nomenclature_indents],
        measures: [
          :base_regulation,
          :modification_regulation,
          {
            goods_nomenclature: %i[goods_nomenclature_descriptions
                                   ns_children
                                   goods_nomenclature_indents],
            geographical_area: %i[geographical_area_descriptions],
          },
        ],
      }
    end
  end
end
