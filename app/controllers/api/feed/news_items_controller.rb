module Api
  module Feed
    class NewsItemsController < ApiController
      def index
        @news_items = NewsItem
          .for_service(service)
          .updates
          .paginate(current_page, per_page)
          .descending
      end

      def service
        params[:service] || ''
      end
    end
  end
end
