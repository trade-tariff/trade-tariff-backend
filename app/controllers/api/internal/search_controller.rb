module Api
  module Internal
    class SearchController < InternalController
      def search
        render json: Api::Internal::SearchService.new(search_params).call
      end

      def suggestions
        render json: Api::Internal::SuggestionsService.new(params).call
      end

      private

      def search_params
        params.permit(:q, :as_of, :request_id, answers: %i[question answer options])
      end
    end
  end
end
