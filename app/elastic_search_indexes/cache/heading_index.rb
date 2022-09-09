module Cache
  class HeadingIndex < ::Cache::CacheIndex
    def dataset
      TimeMachine.now do
        super.actual
      end
    end

    def eager_load_graph
      [
        {
          commodities: %i[
            goods_nomenclature_descriptions
            goods_nomenclature_indents
          ],
        },
        { chapter: [:guides, :goods_nomenclature_descriptions, { section: :section_note }] },
        :goods_nomenclature_indents,
        :goods_nomenclature_descriptions,
        { footnotes: [:footnote_descriptions] },
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
