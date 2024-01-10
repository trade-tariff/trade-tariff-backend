module Api
  module V2
    class SearchReferenceSerializer
      include JSONAPI::Serializer

      set_type :search_reference

      set_id :id

      attributes :title,
                 :referenced_id,
                 :referenced_class,
                 :goods_nomenclature_item_id,
                 :productline_suffix,
                 :goods_nomenclature_sid

      attribute :negated_title, &:title_indexed
    end
  end
end
