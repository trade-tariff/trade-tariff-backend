module Api
  module Beta
    class SearchService
      DEFAULT_SEARCH_INDEX = Search::GoodsNomenclatureIndex.new.name

      def initialize(search_query, search_filters = {})
        @search_query = search_query
        @search_filters = search_filters
      end

      def call
        result = v2_search_client
          .search(index: DEFAULT_SEARCH_INDEX, body: generated_search_query.query)

        search_result = ::Beta::Search::OpenSearchResult.build(
          result,
          search_query_parser_result,
          generated_search_query,
        )

        if search_result.numeric? && search_result.hits.count.zero?
          search_result.redirect!
        end

        search_result.generate_heading_and_chapter_statistics
        search_result.generate_guide_statistics
        search_result.generate_facet_statistics

        search_result
      end

      private

      delegate :v2_search_client, to: TradeTariffBackend

      def generated_search_query
        @generated_search_query ||= ::Beta::Search::GoodsNomenclatureQuery.build(search_query_parser_result, @search_filters)
      end

      def search_query_parser_result
        @search_query_parser_result ||= Api::Beta::SearchQueryParserService.new(@search_query).call
      end
    end
  end
end
