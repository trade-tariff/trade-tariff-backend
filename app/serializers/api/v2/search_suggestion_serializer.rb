module Api
  module V2
    class SearchSuggestionSerializer
      include JSONAPI::Serializer

      set_type :search_suggestion

      attribute :value, :priority, :goods_nomenclature_class
      attribute :suggestion_type, &:type

      attribute :score do |search_suggestion|
        search_suggestion[:score]
      end

      attribute :query do |search_suggestion|
        search_suggestion[:query].to_s.delete('\\')
      end
    end
  end
end
