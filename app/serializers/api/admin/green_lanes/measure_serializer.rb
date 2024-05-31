module Api
  module Admin
    module GreenLanes
      class MeasureSerializer
        include JSONAPI::Serializer

        set_type :green_lanes_measure

        set_id :id

        attribute :productline_suffix

        has_one :category_assessment, serializer: CategoryAssessmentSerializer
        has_one :goods_nomenclature, serializer: GoodsNomenclatureSerializer, id_method_name: :goods_nomenclature_sid
      end
    end
  end
end
