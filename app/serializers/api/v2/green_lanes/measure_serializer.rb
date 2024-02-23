module Api
  module V2
    module GreenLanes
      class MeasureSerializer
        include JSONAPI::Serializer

        set_id :measure_sid

        attributes :effective_start_date,
                   :effective_end_date

        has_one :measure_type, type: :measure_type, serializer: Api::V2::Measures::MeasureTypeSerializer
        has_one :goods_nomenclature, type: :goods_nomenclature, serializer: Api::V2::GoodsNomenclatures::GoodsNomenclatureExtendedSerializer
        has_many :footnotes, type: :footnote, serializer: Api::V2::Measures::FootnoteSerializer
      end
    end
  end
end
