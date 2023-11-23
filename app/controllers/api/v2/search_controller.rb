module Api
  module V2
    class SearchController < ApiController
      include NoCaching

      def search
        render json: SearchService.new(Api::V2::SearchSerializationService.new, params).to_json
      end

      def suggestions
        render json: Api::V2::SearchSuggestionSerializer.new(matching_suggestions).serializable_hash
      end

      private

      def matching_suggestions
        if !SearchService::RogueSearchService.call(params[:q]) && params[:q].present?
          return SearchSuggestion.fuzzy_search(params[:q])
        end

        []
      end
    end
  end
end
