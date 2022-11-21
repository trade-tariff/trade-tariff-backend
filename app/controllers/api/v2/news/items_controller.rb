module Api
  module V2
    module News
      class ItemsController < ApiController
        def index
          news_items = ::News::Item.eager(:collections)
                                   .for_service(params[:service])
                                   .for_target(params[:target])
                                   .for_today
                                   .descending
                                   .paginate(current_page, per_page)

          serializer = Api::V2::News::ItemSerializer.new(news_items, include: %w[collections])

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
end
