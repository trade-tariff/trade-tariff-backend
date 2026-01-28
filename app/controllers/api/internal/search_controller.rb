module Api
  module Internal
    class SearchController < InternalController
      def search
        render json: Api::Internal::SearchService.new(params).call
      end

      def suggestions
        render json: Api::Internal::SuggestionsService.new(params).call
      end
    end
  end
end
