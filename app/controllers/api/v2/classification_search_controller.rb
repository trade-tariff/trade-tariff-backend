module Api
  module V2
    class ClassificationSearchController < ApiController
      no_caching

      def search
        result = ClassificationSearchService.new(params).call

        if result.is_a?(Hash) && result[:errors]
          render json: result, status: :unprocessable_content
        else
          render json: result
        end
      rescue HybridRetrievalService::AllLegsFailed => e
        render json: {
          errors: [
            {
              status: '500',
              title: 'Classification search failed',
              detail: e.message,
            },
          ],
        }, status: :internal_server_error
      end
    end
  end
end
