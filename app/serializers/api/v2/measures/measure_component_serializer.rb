module Api
  module V2
    module Measures
      class MeasureComponentSerializer
        include JSONAPI::Serializer

        set_type :measure_component

        attributes :duty_expression_id,
                   :duty_amount,
                   :monetary_unit_code,
                   :monetary_unit_abbreviation,
                   :measurement_unit_code,
                   :measurement_unit_qualifier_code,
                   :duty_expression_description,
                   :duty_expression_abbreviation

        has_one :measurement_unit, serializer: Api::V2::Measures::MeasurementUnitSerializer, if: proc { |measure_component| measure_component.measurement_unit_code.present? }
      end
    end
  end
end
