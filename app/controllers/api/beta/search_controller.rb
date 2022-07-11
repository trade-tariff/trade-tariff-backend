module Api
  module Beta
    class SearchController < ApiController
      def index
        render json: Beta::SearchService.new(search_query).call
      end

      private

      def search_query
        params[:q]
      end
    end
  end
end
