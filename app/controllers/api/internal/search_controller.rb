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
      rescue HybridRetrievalService::AllLegsFailed
        render json: {
          errors: [
            {
              status: '500',
              title: 'Search failed',
              detail: 'Search is temporarily unavailable',
            },
          ],
        }, status: :internal_server_error
      end

      def suggestions
        render json: Api::Internal::SuggestionsService.new(params).call
      end

    private

      def search_params
        params.permit(:q, :as_of, :request_id, :expanded_query, :skip_question, answers: %i[question answer options])
      end
    end
  end
end
