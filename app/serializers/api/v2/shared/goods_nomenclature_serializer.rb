module Api
  module V2
    module Shared
      class GoodsNomenclatureSerializer
        include JSONAPI::Serializer

        set_id :goods_nomenclature_sid

        attributes :goods_nomenclature_item_id,
                   :producline_suffix,
                   :description,
                   :formatted_description
      end
    end
  end
end
