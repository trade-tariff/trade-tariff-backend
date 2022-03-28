module Api
  module V2
    module Shared
      class MeasureSerializer
        include JSONAPI::Serializer

        set_type :measure

        set_id :measure_sid

        attributes :goods_nomenclature_item_id,
                   :validity_end_date,
                   :validity_start_date

        has_one :goods_nomenclature,
                serializer: proc { |record, _params|
                  if record && record.respond_to?(:goods_nomenclature_class)
                    "Api::V2::Shared::#{record.goods_nomenclature_class}Serializer".constantize
                  else
                    Api::V2::Shared::GoodsNomenclatureSerializer
                  end
                }

        has_one :geographical_area, serializer: Api::V2::GeographicalAreaSerializer
      end
    end
  end
end
