module Api
  module Admin
    module News
      class ItemsController < AdminController
        include Api::Admin::ResourceActions

        def index
          render json: serialize(news_items.to_a, pagination_meta)
        end

        private

        def serializer_class = Api::Admin::News::ItemSerializer
        def resource_class = ::News::Item

        def resource_params
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
            :notify_subscribers,
            collection_ids: [],
          )
        end

        def pagination_meta
          {
            meta: {
              pagination: {
                page: current_page,
                per_page:,
                total_count: news_items.pagination_record_count,
              },
            },
          }
        end

        def news_items
          @news_items ||= ::News::Item.eager(:collections).descending.paginate(current_page, per_page)
        end
      end
    end
  end
end
