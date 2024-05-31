module Api
  module Admin
    module GreenLanes
      class GoodsNomenclatureSerializer
        include JSONAPI::Serializer

        set_type :green_lanes_goods_nomenclature

        set_id :goods_nomenclature_sid

        attributes :description, :goods_nomenclature_sid
      end
    end
  end
end
