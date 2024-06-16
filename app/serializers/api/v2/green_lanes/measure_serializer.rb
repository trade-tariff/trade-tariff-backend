module Api
  module V2
    module GreenLanes
      class MeasureSerializer
        include JSONAPI::Serializer

        set_id :measure_sid

        attributes :effective_start_date,
                   :effective_end_date,
                   :goods_nomenclature_sid

        has_one :measure_type, serializer: Measures::MeasureTypeSerializer
        has_many :footnotes, serializer: Measures::FootnoteSerializer
      end
    end
  end
end
