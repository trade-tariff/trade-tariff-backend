module Api
  module Admin
    module SearchReferences
      class SearchReferenceSerializer
        include JSONAPI::Serializer

        set_type :search_reference

        set_id :id

        attributes :title, :referenced_id, :referenced_class

        has_one :referenced, polymorphic: true
      end
    end
  end
end
