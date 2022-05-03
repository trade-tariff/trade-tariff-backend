module Api
  module V2
    class SearchReferenceSerializer
      include JSONAPI::Serializer

      set_type :search_reference

      set_id :id

      attributes :title, :referenced_id, :referenced_class, :productline_suffix
    end
  end
end
