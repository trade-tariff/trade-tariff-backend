module Api
  module Admin
    module GreenLanes
      class MeasureSerializer
        include JSONAPI::Serializer

        set_type :green_lanes_measure

        set_id :id

        attribute :category_assessment_id
        attribute :goods_nomenclature_item_id
        attribute :productline_suffix
      end
    end
  end
end
