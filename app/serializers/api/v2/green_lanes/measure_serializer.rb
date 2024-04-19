module Api
  module V2
    module GreenLanes
      class MeasureSerializer
        include JSONAPI::Serializer

        set_id :measure_sid

        attributes :effective_start_date,
                   :effective_end_date

        has_one :measure_type, serializer: Measures::MeasureTypeSerializer
        has_one :measure_generating_regulation, serializer: Measures::MeasureLegalActSerializer
        has_one :additional_code, serializer: AdditionalCodeSerializer
        has_many :footnotes, serializer: Measures::FootnoteSerializer
      end
    end
  end
end
