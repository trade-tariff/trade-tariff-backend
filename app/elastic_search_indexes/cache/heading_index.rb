module Cache
  class HeadingIndex < ::Cache::CacheIndex
    def eager_load_graph
      [
        {
          commodities: [
            :goods_nomenclature_descriptions,
            :goods_nomenclature_indents,
            { heading: [:commodities] }, # TODO: We should be able to replace loading the heading and its commodities with the materialized path concept and avoid eager loading for the goods nomenclature mapper
          ],
        },
        { chapter: [:guides, :goods_nomenclature_descriptions, { section: :section_note }] },
        :goods_nomenclature_indents,
        :goods_nomenclature_descriptions,
        :footnotes,
      ]
    end

    def definition
      {
        mappings: {
          dynamic: false,
          properties: {},
        },
      }
    end
  end
end
