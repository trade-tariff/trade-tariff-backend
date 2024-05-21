module Api
  module Admin
    module GreenLanes
      class GoodsNomenclatureSerializer
        include JSONAPI::Serializer

        set_type :green_lanes_goods_nomenclature

        set_id :goods_nomenclature_item_id

        attributes :description, :goods_nomenclature_item_id

      end
    end
  end
end
