module Api
  module V2
    module QuotaOrderNumbers
      class MeasureSerializer
        include JSONAPI::Serializer

        set_type :measure

        set_id :measure_sid

        attributes :goods_nomenclature_item_id
      end
    end
  end
end
