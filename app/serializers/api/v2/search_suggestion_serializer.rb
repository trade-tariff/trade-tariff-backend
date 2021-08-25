module Api
  module V2
    class SearchSuggestionSerializer
      include JSONAPI::Serializer

      set_type :search_suggestion

      attribute :value
    end
  end
end
