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

          serializer = Api::V2::News::ItemSerializer.new(news_items,
                                                         include: %w[collections],
                                                         meta: pagination_meta(news_items))

          render json: serializer.serializable_hash
        end

        def show
          news_item = ::News::Item.for_today.with_pk!(params[:id])

          serializer = Api::V2::News::ItemSerializer.new(news_item)

          render json: serializer.serializable_hash
        end

      private

        def per_page
          10
        end

        def pagination_meta(data_set)
          {
            pagination: {
              page: current_page,
              per_page:,
              total_count: data_set.pagination_record_count,
            },
          }
        end
      end
    end
  end
end
