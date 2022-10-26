module Api
  module Beta
    class SearchQueryParserService
      delegate :client, to: :class

      def initialize(original_search_query, spell: '1', goods_nomenclature_item_id_match: false)
        @original_search_query = original_search_query
        @spell = spell
        @goods_nomenclature_item_id_match = goods_nomenclature_item_id_match
      end

      def call
        if null_result?
          ::Beta::Search::SearchQueryParserResult::Null.build('original_search_query' => original_search_query)
        else
          result_attributes = client.get('tokens', q: original_search_query, spell:).body

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

      attr_reader :original_search_query, :spell

      def null_result?
        original_search_query.blank? || @goods_nomenclature_item_id_match || AggregatedSynonym.exists?(@original_search_query)
      end
    end
  end
end
