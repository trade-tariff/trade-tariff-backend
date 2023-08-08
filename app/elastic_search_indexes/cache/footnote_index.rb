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
      eager_load_measures.merge(
        footnote_descriptions: {},
        goods_nomenclatures: %i[goods_nomenclature_descriptions
                                children
                                goods_nomenclature_indents],
      )
    end
  end
end
