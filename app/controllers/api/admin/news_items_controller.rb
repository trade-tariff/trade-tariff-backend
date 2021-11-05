module Api
  module Admin
    class NewsItemsController < ApiController
      before_action :authenticate_user!

      def index
        render json: serialize(collection.to_a, pagination_meta)
      end

      def show
        news_item = NewsItem.with_pk!(params[:id])

        render json: serialize(news_item)
      end

      def create
        news_item = NewsItem.new(news_item_params[:attributes])

        if news_item.valid? && news_item.save
          render json: serialize(news_item),
                 location: api_admin_news_item_url(news_item.id),
                 status: :created
        else
          render json: serialize_errors(news_item.errors),
                 status: :unprocessable_entity
        end
      end

      def update
        news_item = NewsItem.with_pk!(params[:id])
        news_item.set news_item_params[:attributes]

        if news_item.valid? && news_item.save
          render json: serialize(news_item),
                 location: api_admin_news_item_url(news_item.id),
                 status: :ok
        else
          render json: serialize_errors(news_item.errors),
                 status: :unprocessable_entity
        end
      end

      def destroy
        news_item = NewsItem.with_pk!(params[:id])
        news_item.destroy

        head :no_content
      end

      private

      def news_item_params
        params.require(:data).permit(:type, attributes: %i[
          start_date
          end_date
          title
          content
          show_on_xi
          show_on_uk
          show_on_updates_page
          show_on_home_page
          display_style
        ])
      end

      def collection
        @collection ||= NewsItem.descending.paginate(current_page, per_page)
      end

      def pagination_meta
        {
          meta: {
            pagination: {
              page: current_page,
              per_page: per_page,
              total_count: @collection.pagination_record_count,
            },
          },
        }
      end

      def serialize(*args)
        Api::Admin::NewsItemSerializer.new(*args).serializable_hash
      end

      def serialize_errors(errors)
        Api::V2::ErrorSerializationService.new.serialized_errors(errors)
      end
    end
  end
end
