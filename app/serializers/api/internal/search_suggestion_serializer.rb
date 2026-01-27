module Api
  module Internal
    class SearchSuggestionSerializer
      include JSONAPI::Serializer

      set_type :search_suggestion

      attribute :value, :priority, :goods_nomenclature_class
      attribute :suggestion_type, &:type

      attribute :score do |suggestion|
        suggestion[:score]
      end

      attribute :query do |suggestion|
        suggestion[:query].to_s.delete('\\')
      end
    end
  end
end
