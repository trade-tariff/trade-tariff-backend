module Api
  module V2
    module GreenLanes
      class SubheadingMeasuresSerializer
        include JSONAPI::Serializer

        set_type :subheading_measures

        set_id :goods_nomenclature_sid

        has_one :subheading, serializer: Api::V2::GreenLanes::SubheadingSerializer
        has_many :applicable_measures, record_type: :measure, serializer: Api::V2::Declarable::MeasureSerializer
      end
    end
  end
end
