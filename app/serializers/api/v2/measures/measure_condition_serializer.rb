module Api
  module V2
    module Measures
      class MeasureConditionSerializer
        include JSONAPI::Serializer

        set_type :measure_condition

        set_id :measure_condition_sid

        attributes :condition_code,
                   :condition,
                   :document_code,
                   :requirement,
                   :action,
                   :action_code,
                   :duty_expression,
                   :condition_duty_amount,
                   :condition_monetary_unit_code,
                   :monetary_unit_abbreviation,
                   :condition_measurement_unit_code,
                   :condition_measurement_unit_qualifier_code

        has_many :measure_condition_components, serializer: Api::V2::Measures::MeasureConditionComponentSerializer
      end
    end
  end
end
