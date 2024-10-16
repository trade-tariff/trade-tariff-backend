module Api
  module V2
    module Measures
      class MeasureConditionComponentSerializer
        include JSONAPI::Serializer

        set_type :measure_condition_component

        attributes :duty_expression_id,
                   :duty_amount,
                   :monetary_unit_code,
                   :monetary_unit_abbreviation,
                   :measurement_unit_code,
                   :measurement_unit_qualifier_code,
                   :duty_expression_description,
                   :duty_expression_abbreviation,
                   :measure_condition_sid
      end
    end
  end
end
