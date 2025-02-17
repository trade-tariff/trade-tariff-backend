module Api
  module V2
    class SearchController < ApiController
      no_caching

      def search
        render json: SearchService.new(Api::V2::SearchSerializationService.new, params).to_json
      end

      def suggestions
        if TradeTariffBackend.optimised_search_enabled?
          render json: ElasticSearch::ElasticSearchService.new(params).to_suggestions
        else
          render json: Api::V2::SearchSuggestionSerializer.new(matching_suggestions).serializable_hash
        end
      end

      private

      def matching_suggestions
        if params[:q].present? && !SearchService::RogueSearchService.call(params[:q])
          return SearchSuggestion.fuzzy_search(params[:q])
        end

        []
      end
    end
  end
end
