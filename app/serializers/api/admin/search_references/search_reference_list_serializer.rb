module Api
  module Admin
    module SearchReferences
      class SearchReferenceListSerializer
        include JSONAPI::Serializer

        set_type :search_reference

        set_id :id

        attributes :title,
                   :referenced_id,
                   :referenced_class,
                   :goods_nomenclature_item_id,
                   :productline_suffix,
                   :goods_nomenclature_sid
      end
    end
  end
end
