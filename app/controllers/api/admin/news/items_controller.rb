module Api
  module Admin
    module News
      class ItemsController < AdminController
        before_action :authenticate_user!

        def index
          render json: serialize(news_items.to_a, pagination_meta)
        end

        def show
          news_item = ::News::Item.with_pk!(params[:id])

          render json: serialize(news_item)
        end

        def create
          news_item = ::News::Item.new(news_item_params)

          if news_item.valid? && news_item.save
            render json: serialize(news_item),
                   location: api_admin_news_item_url(news_item.id),
                   status: :created
          else
            render json: serialize_errors(news_item),
                   status: :unprocessable_entity
          end
        end

        def update
          news_item = ::News::Item.with_pk!(params[:id])
          news_item.set news_item_params

          if news_item.valid? && news_item.save
            render json: serialize(news_item),
                   location: api_admin_news_item_url(news_item.id),
                   status: :ok
          else
            render json: serialize_errors(news_item),
                   status: :unprocessable_entity
          end
        end

        def destroy
          news_item = ::News::Item.with_pk!(params[:id])
          news_item.destroy

          head :no_content
        end

        private

        def news_item_params
          params.require(:data).require(:attributes).permit(
            :start_date,
            :end_date,
            :title,
            :content,
            :slug,
            :precis,
            :show_on_xi,
            :show_on_uk,
            :show_on_updates_page,
            :show_on_home_page,
            :show_on_banner,
            :display_style,
            :chapters,
            collection_ids: [],
          )
        end

        def news_items
          @news_items ||= ::News::Item.eager(:collections)
                                      .descending
                                      .paginate(current_page, per_page)
        end

        def pagination_meta
          {
            meta: {
              pagination: {
                page: current_page,
                per_page:,
                total_count: @news_items.pagination_record_count,
              },
            },
          }
        end

        def serialize(*args)
          Api::Admin::News::ItemSerializer.new(*args).serializable_hash
        end

        def serialize_errors(news_item)
          Api::Admin::ErrorSerializationService.new(news_item).call
        end
      end
    end
  end
end
