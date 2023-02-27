module Api
  module Beta
    class SearchQueryParserResultSerializer
      include JSONAPI::Serializer

      set_type :search_query_parser_result

      attributes :corrected_search_query,
                 :original_search_query,
                 :expanded_search_query,
                 :verbs,
                 :adjectives,
                 :nouns,
                 :noun_chunks,
                 :null_result
    end
  end
end
