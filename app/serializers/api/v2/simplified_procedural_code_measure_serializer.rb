module Api
  module V2
    class SimplifiedProceduralCodeMeasureSerializer
      include JSONAPI::Serializer

      set_id :simplified_procedural_code

      set_type :simplified_procedural_code_measure

      attributes :validity_start_date,
                 :validity_end_date,
                 :duty_amount,
                 :goods_nomenclature_label,
                 :goods_nomenclature_item_ids,
                 :monetary_unit_code,
                 :measurement_unit_code,
                 :measurement_unit_qualifier_code
    end
  end
end
