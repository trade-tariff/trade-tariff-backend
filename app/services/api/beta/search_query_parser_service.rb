module Api
  module Beta
    class SearchQueryParserService
      delegate :client, to: :class

      def initialize(original_search_query)
        @original_search_query = original_search_query
      end

      def call
        if null_result?
          ::Beta::Search::SearchQueryParserResult::Null.build('original_search_query' => @original_search_query)
        else
          result_attributes = client.get('tokens', q: @original_search_query).body

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

      def null_result?
        @original_search_query.blank? || AggregatedSynonym.exists?(@original_search_query)
      end
    end
  end
end
