module Cache
  class CacheIndex < ::SearchIndex
    include PointInTimeIndex

    def name
      "#{super}-cache"
    end

    def page_size
      50
    end

    def hidden_codes
      @hidden_codes ||= HiddenGoodsNomenclature.codes
    end

    def serialize_record(record)
      serializer.new(record, hidden_codes).as_json
    end

  private

    def eager_load_measures
      {
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
