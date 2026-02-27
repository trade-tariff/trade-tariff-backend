module Api
  module Admin
    module GoodsNomenclatures
      class GoodsNomenclatureLabelSerializer
        include JSONAPI::Serializer

        set_type :goods_nomenclature_label

        set_id :goods_nomenclature_sid

        attributes :goods_nomenclature_sid,
                   :goods_nomenclature_item_id,
                   :goods_nomenclature_type,
                   :producline_suffix,
                   :stale,
                   :manually_edited,
                   :context_hash

        attribute :labels do |label|
          label.labels || {}
        end
      end
    end
  end
end
