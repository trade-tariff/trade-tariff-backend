module Api
  module V2
    module Quotas
      module Definition
        class MeasureSerializer
          include JSONAPI::Serializer

          set_type :measure

          set_id :measure_sid

          attribute :goods_nomenclature_item_id

          has_one :goods_nomenclature, serializer: proc { |record, _params| "Api::V2::Quotas::Definition::#{record.goods_nomenclature_class}Serializer".constantize }

          has_one :geographical_area, serializer: Api::V2::GeographicalAreaSerializer
        end
      end
    end
  end
end
