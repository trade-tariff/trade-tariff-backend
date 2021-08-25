module Api
  module V2
    class ExactSearchSerializer
      include JSONAPI::Serializer

      set_type :exact_search

      attributes :type, :entry
    end
  end
end
