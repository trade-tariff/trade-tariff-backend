module Api
  module Beta
    class SearchService
      DEFAULT_INCLUDES = [
        'hits.ancestors',
        :search_query_parser_result,
        :heading_statistics,
        :chapter_statistics,
        :guide,
      ].freeze
      DEFAULT_SEARCH_INDEX = 'tariff-goods_nomenclatures'.freeze

      def initialize(search_query)
        @search_query = search_query
      end

      def call
        result = v2_search_client
          .search(index: DEFAULT_SEARCH_INDEX, body: generated_search_query)

        search_result = ::Beta::Search::OpenSearchResult.build(result, search_query_parser_result)
        search_result.generate_statistics
        search_result.generate_guide_statistics

        Api::Beta::SearchResultSerializer.new(search_result, include: DEFAULT_INCLUDES).serializable_hash
      end

      private

      delegate :v2_search_client, to: TradeTariffBackend

      def generated_search_query
        @generated_search_query ||= ::Beta::Search::GoodsNomenclatureQuery.build(search_query_parser_result).query
      end

      def search_query_parser_result
        @search_query_parser_result ||= Api::Beta::SearchQueryParserService.new(@search_query).call
      end
    end
  end
end
