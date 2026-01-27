module Search
  class SearchSuggestionsSerializer < ::Serializer
    def serializable_hash(_opts = {})
      {
        value:,
        suggestion_type: type,
        priority:,
        goods_nomenclature_sid:,
        goods_nomenclature_class:,
      }
    end
  end
end
