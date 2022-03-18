module Api
  module V2
    module Quotas
      module Definition
        class GoodsNomenclatureSerializer
          include JSONAPI::Serializer

          set_type :goods_nomenclature
          set_id :goods_nomenclature_sid

          attributes :goods_nomenclature_class,
                     :goods_nomenclature_item_id,
                     :producline_suffix
        end
      end
    end
  end
end
