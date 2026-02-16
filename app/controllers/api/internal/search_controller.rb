module Api
  module Internal
    class SearchController < InternalController
      def search
        result = Api::Internal::SearchService.new(search_params).call

        if result.is_a?(Hash) && result[:errors]
          render json: result, status: :unprocessable_content
        else
          render json: result
        end
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
