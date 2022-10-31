module Api
  module V2
    class ValidityPeriodSerializer
      include JSONAPI::Serializer

      set_type :validity_period

      attributes :goods_nomenclature_item_id,
                 :producline_suffix,
                 :validity_start_date,
                 :validity_end_date,
                 :to_param
    end
  end
end
