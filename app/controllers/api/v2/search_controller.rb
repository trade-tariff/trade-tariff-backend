module Api
  module V2
    class SearchController < ApiController
      no_caching

      def search
        results = SearchService.new(Api::V2::SearchSerializationService.new, params).to_json
        instrumentation_service.log_search_results(results)
        render json: results
      end

      def suggestions
        results = if TradeTariffBackend.optimised_search_enabled?
                    ElasticSearch::ElasticSearchService.new(params).to_suggestions
                  else
                    Api::V2::SearchSuggestionSerializer.new(matching_suggestions).serializable_hash
                  end
        instrumentation_service.log_search_suggestions_results(results)
        render json: results
      end

      private

      def instrumentation_service
        @instrumentation_service ||= SearchInstrumentationService.new(params[:q])
      end

      def matching_suggestions
        if params[:q].present? && !SearchService::RogueSearchService.call(params[:q])
          return SearchSuggestion.fuzzy_search(params[:q])
        end

        []
      end

      # https://www.trade-tariff.service.gov.uk/api/uk/suggestions?q="0101"&filter[type]=goods_nomenclature&filter[goods_nomenclature_class]=Heading,Commodity
      def suggestion_params
        params.permit(:q, :filter)
      end
    end
  end
end
