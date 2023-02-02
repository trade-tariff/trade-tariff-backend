module Api
  module Admin
    module SearchReferences
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

        has_one :referenced, polymorphic: true
      end
    end
  end
end
