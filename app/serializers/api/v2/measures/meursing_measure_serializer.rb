module Api
  module V2
    module Measures
      class MeursingMeasureSerializer
        include JSONAPI::Serializer

        set_type :measure

        set_id :measure_sid

        attributes :reduction_indicator,
                   :formatted_duty_expression

        has_one :geographical_area, serializer: Api::V2::Measures::GeographicalAreaSerializer
        has_one :measure_type, serializer: Api::V2::Measures::MeasureTypeSerializer
        has_many :measure_components, serializer: Api::V2::Measures::MeasureComponentSerializer
        has_one :additional_code, serializer: Api::V2::AdditionalCodeSerializer
      end
    end
  end
end
