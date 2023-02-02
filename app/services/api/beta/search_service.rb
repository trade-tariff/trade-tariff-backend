module Api
  module Beta
    class SearchService
      DEFAULT_SEARCH_INDEX = Search::GoodsNomenclatureIndex.new.name
      GOOD_NOMENCLATURE_ITEM_ID_SEARCH = /^(\d+)(-\d{2})?$/

      def initialize(search_query, search_params = {})
        @search_query = search_query.to_s
        @search_params = search_params
      end

      def call
        if redirect?
          search_result.redirect!
        end

        search_result.generate_heading_and_chapter_statistics
        search_result.generate_guide_statistics if TradeTariffBackend.beta_search_guides_enabled?
        search_result.generate_facet_statistics

        search_result
      end

      private

      delegate :v2_search_client, to: TradeTariffBackend

      def search_result
        @search_result ||= if should_search?
                             ::Beta::Search::OpenSearchResult::WithHits.build(
                               fetch_result,
                               search_query_parser_result,
                               generated_search_query,
                               nil,
                             )
                           else
                             ::Beta::Search::OpenSearchResult::NoHits.build(
                               nil,
                               search_query_parser_result,
                               generated_search_query,
                               exact_search_reference_match.first,
                             )
                           end
      end

      def fetch_result
        v2_search_client.search(index: DEFAULT_SEARCH_INDEX, body: generated_search_query.query)
      end

      def generated_search_query
        @generated_search_query ||= ::Beta::Search::GoodsNomenclatureQuery.build(search_query_parser_result, @search_params[:filters])
      end

      def search_query_parser_result
        @search_query_parser_result ||= Api::Beta::SearchQueryParserService.new(@search_query, spell: @search_params[:spell], should_search: should_search?).call
      end

      def should_search?
        !(@search_query.blank? || redirect?)
      end

      def redirect?
        goods_nomenclature_item_id_match? || exact_search_reference_match?
      end

      def goods_nomenclature_item_id_match?
        @search_query.match?(GOOD_NOMENCLATURE_ITEM_ID_SEARCH)
      end

      def exact_search_reference_match?
        exact_search_reference_match.one?
      end

      def exact_search_reference_match
        @exact_search_reference_match ||= SearchReference.where(title: normalised_search_query).limit(2)
      end

      def normalised_search_query
        @normalised_search_query ||= @search_query.downcase.scan(/\w+/).join(' ')
      end
    end
  end
end
