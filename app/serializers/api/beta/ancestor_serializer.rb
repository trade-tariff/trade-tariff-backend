module Api
  module Beta
    class AncestorSerializer
      include JSONAPI::Serializer

      set_type :ancestor

      attributes :goods_nomenclature_item_id,
                 :producline_suffix,
                 :description,
                 :description_indexed,
                 :goods_nomenclature_class
    end
  end
end
