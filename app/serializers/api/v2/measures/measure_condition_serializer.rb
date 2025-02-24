module Api
  module V2
    module Measures
      class MeasureConditionSerializer
        include JSONAPI::Serializer

        set_type :measure_condition

        set_id :measure_condition_sid

        attributes :action,
                   :action_code,
                   :certificate_description,
                   :condition,
                   :condition_code,
                   :condition_duty_amount,
                   :condition_measurement_unit_code,
                   :condition_measurement_unit_qualifier_code,
                   :condition_monetary_unit_code,
                   :document_code,
                   :duty_expression,
                   :guidance_cds,
                   #  :guidance_chief,
                   :measure_condition_class,
                   :monetary_unit_abbreviation,
                   :requirement,
                   :requirement_operator,
                   :threshold_unit_type

        has_many :measure_condition_components, serializer: Api::V2::Measures::MeasureConditionComponentSerializer
      end
    end
  end
end
