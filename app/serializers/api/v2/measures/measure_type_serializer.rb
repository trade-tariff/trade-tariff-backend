module Api
  module V2
    module Measures
      class MeasureTypeSerializer
        include JSONAPI::Serializer

        set_type :measure_type

        set_id :measure_type_id

        attributes :description,
                   :measure_type_series_id,
                   :measure_component_applicable_code,
                   :order_number_capture_code,
                   :trade_movement_code,
                   :validity_end_date,
                   :validity_start_date

        attribute :id, &:measure_type_id

        attribute :measure_type_series_description do |measure_type|
          measure_type.measure_type_series_description&.description
        end
      end
    end
  end
end
