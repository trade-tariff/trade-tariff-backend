module Beta
  module Search
    class SearchQueryParserResult
      include ActiveModel::Model
      include ContentAddressableId

      content_addressable_fields :original_search_query

      attr_accessor :adjectives,
                    :nouns,
                    :verbs,
                    :noun_chunks,
                    :original_search_query,
                    :corrected_search_query,
                    :expanded_search_query,
                    :null_result

      class Standard
        def self.build(attributes)
          search_query_parser_result = SearchQueryParserResult.new

          attributes = JSON.parse(attributes) if attributes.is_a?(String)

          search_query_parser_result.original_search_query = attributes['original_search_query']
          search_query_parser_result.corrected_search_query = attributes['corrected_search_query']
          search_query_parser_result.expanded_search_query = attributes['expanded_search_query']
          search_query_parser_result.adjectives = attributes.dig('tokens', 'adjectives')
          search_query_parser_result.nouns = attributes.dig('tokens', 'nouns')
          search_query_parser_result.verbs = attributes.dig('tokens', 'verbs')
          search_query_parser_result.noun_chunks = attributes.dig('tokens', 'noun_chunks')
          search_query_parser_result.null_result = false

          search_query_parser_result
        end
      end

      class Null
        def self.build(attributes)
          search_query_parser_result = SearchQueryParserResult.new

          search_query_parser_result.original_search_query = attributes['original_search_query']
          search_query_parser_result.corrected_search_query = attributes['original_search_query']
          search_query_parser_result.expanded_search_query = attributes['original_search_query']
          search_query_parser_result.adjectives = []
          search_query_parser_result.nouns = []
          search_query_parser_result.verbs = []
          search_query_parser_result.noun_chunks = [attributes['original_search_query']]
          search_query_parser_result.null_result = true

          search_query_parser_result
        end
      end
    end
  end
end
