module Api
  module Admin
    class GoodsNomenclatureAutocompleteSerializer
      include JSONAPI::Serializer

      set_type :goods_nomenclature_autocomplete
      set_id :goods_nomenclature_sid

      attribute :goods_nomenclature_sid, &:goods_nomenclature_sid
      attribute :goods_nomenclature_item_id, &:value

      attribute :producline_suffix do |record|
        record.goods_nomenclature&.producline_suffix
      end

      attribute :description do |record|
        record.goods_nomenclature&.description
      end
    end
  end
end
