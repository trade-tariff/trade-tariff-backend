module Beta
  module Search
    class SearchQueryParserResult
      include ActiveModel::Model

      attr_accessor :adjectives,
                    :nouns,
                    :verbs,
                    :noun_chunks,
                    :original_search_query,
                    :corrected_search_query

      def self.build(attributes)
        search_query_parser_result = new

        attributes = JSON.parse(attributes) if attributes.is_a?(String)

        search_query_parser_result.original_search_query = attributes['original_search_query']
        search_query_parser_result.corrected_search_query = attributes['corrected_search_query']
        search_query_parser_result.adjectives = attributes.dig('tokens', 'adjectives')
        search_query_parser_result.nouns = attributes.dig('tokens', 'nouns')
        search_query_parser_result.verbs = attributes.dig('tokens', 'verbs')
        search_query_parser_result.noun_chunks = attributes.dig('tokens', 'noun_chunks')

        search_query_parser_result
      end

      def id
        Digest::MD5.hexdigest(original_search_query)
      end
    end
  end
end
