module Api
  module V2
    class ValidityPeriodSerializer
      include JSONAPI::Serializer

      set_type :validity_period
      set_id   :validity_period_id

      attributes :goods_nomenclature_item_id, :validity_start_date, :validity_end_date
    end
  end
end
