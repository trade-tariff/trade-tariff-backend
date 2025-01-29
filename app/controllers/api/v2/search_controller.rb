module Api
  module V2
    class SearchController < ApiController
      no_caching

      elastic_search = true

      def search
        render json: SearchService.new(Api::V2::SearchSerializationService.new, params).to_json
      end

      def suggestions
        if elastic_search
          render json: ElasticSearchService.new(params).to_suggestions
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

      def elastic_search
        # code here
        true
      end
    end
  end
end
