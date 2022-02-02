module Api
  module V2
    module Measures
      class OverviewMeasureSerializer
        include JSONAPI::Serializer

        set_type :measure

        set_id :measure_sid

        attribute :id, &:measure_sid
        attributes :vat

        has_one :duty_expression, serializer: Api::V2::Measures::DutyExpressionSerializer
        has_one :measure_type, serializer: Api::V2::Measures::MeasureTypeSerializer
      end
    end
  end
end
