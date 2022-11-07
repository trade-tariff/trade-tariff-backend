module Api
  module V2
    class BaseMeasureSerializer
      include JSONAPI::Serializer

      set_type :measure

      set_id :measure_sid

      attributes :origin,
                 :import,
                 :export

      has_one :duty_expression, serializer: Api::V2::Measures::DutyExpressionSerializer
      has_one :measure_type, serializer: Api::V2::Measures::MeasureTypeSerializer
      has_many :legal_acts, serializer: Api::V2::Measures::MeasureLegalActSerializer
      has_many :measure_conditions, serializer: Api::V2::Measures::MeasureConditionSerializer
      has_many :measure_components, serializer: Api::V2::Measures::MeasureComponentSerializer
      has_one :geographical_area, serializer: Api::V2::Measures::GeographicalAreaSerializer
      has_many :footnotes, serializer: Api::V2::Measures::FootnoteSerializer
      has_one :order_number, serializer: Api::V2::Quotas::OrderNumber::QuotaOrderNumberSerializer
    end

  end
end
