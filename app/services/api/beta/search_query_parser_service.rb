module Api
  module Beta
    class SearchQueryParserService
      delegate :client, to: :class

      def initialize(original_search_query)
        @original_search_query = original_search_query
      end

      def call
        if matches_synonym?
          ::Beta::Search::SearchQueryParserResult::Synonym.build(original_search_query:)
        else
          result_attributes = client.get('tokens', q: original_search_query).body

          ::Beta::Search::SearchQueryParserResult::Standard.build(result_attributes)
        end
      end

      def self.client
        @client ||= Faraday.new(TradeTariffBackend.search_query_parser_url) do |conn|
          conn.response :raise_error
          conn.response :json
        end
      end

      private

      attr_reader :original_search_query

      def matches_synonym?
        Api::Beta::SearchSynonymMatcherService.new(@original_search_query).call
      end
    end
  end
end
