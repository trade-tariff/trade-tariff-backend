module Api
  module Beta
    class SearchService
      DEFAULT_INCLUDES = ['hits.ancestors', :search_query_parser_result].freeze
      DEFAULT_SEARCH_INDEX = 'tariff-goods_nomenclatures'.freeze

      def initialize(search_query)
        @search_query = search_query
      end

      def call
        result = v2_search_client
          .search(index: DEFAULT_SEARCH_INDEX, body: generated_search_query)

        result = ::Beta::Search::SearchResult.build(result, search_query_parser_result)

        Api::Beta::SearchResultSerializer.new(result, include: DEFAULT_INCLUDES).serializable_hash
      end

      private

      delegate :v2_search_client, to: TradeTariffBackend

      def generated_search_query
        @generated_search_query ||= ::Beta::Search::GoodsNomenclatureQuery.build(search_query_parser_result).query
      end

      def search_query_parser_result
        @search_query_parser_result ||= SearchQueryParser.new(@search_query).call
      end
    end
  end
end
