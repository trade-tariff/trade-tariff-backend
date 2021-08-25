module Api
  module Admin
    module SearchReferences
      class SearchReferenceListSerializer
        include JSONAPI::Serializer

        set_type :search_reference

        set_id :id

        attributes :title, :referenced_id, :referenced_class
      end
    end
  end
end
