module Api
  module V2
    class NewsItemsController < ApiController
      def index
        news_items = ::News::Item.for_service(params[:service])
                             .for_target(params[:target])
                             .for_today
                             .paginate(current_page, per_page)
                             .descending

        serializer = Api::V2::News::ItemSerializer.new(news_items)

        render json: serializer.serializable_hash
      end

      def show
        news_item = ::News::Item.for_today.with_pk!(params[:id])

        serializer = Api::V2::News::ItemSerializer.new(news_item)

        render json: serializer.serializable_hash
      end
    end
  end
end
