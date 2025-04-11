module Api
  module V2
    module News
      class ItemsController < ApiController
        PAGE_SIZES = [1, 10, 20].freeze
        DEFAULT_PAGE_SIZE = 20

        def index
          return unless stale? ::News::Item.latest_change

          news_items_page = ::News::Item.for_service(params[:service])
                                   .for_target(params[:target])
                                   .for_year(params[:year])
                                   .for_collection(params[:collection_id])
                                   .for_today
                                   .descending
                                   .distinct
                                   .select { [news_items[:id], news_items[:start_date]] }
                                   .paginate(current_page, per_page)

          # Why? you may ask - because #paginate ignores #eager
          news_items_with_collections = ::News::Item.eager(:published_collections)
                                                    .where(id: news_items_page.pluck(:id))
                                                    .descending
                                                    .all

          presented_news_items = Api::V2::News::ItemPresenter.wrap(news_items_with_collections)

          serializer = Api::V2::News::ItemSerializer.new(presented_news_items,
                                                         include: %i[collections],
                                                         meta: pagination_meta(news_items_page))

          render json: serializer.serializable_hash
        end

        def show
          scope = ::News::Item.for_today.for_collection(nil)

          slug_or_id = params[:id]

          news_item = if slug_or_id.present? && !/\A\d+\z/.match?(slug_or_id)
                        scope.where { news_items[:slug] =~ slug_or_id }.take
                      else
                        scope.with_pk!(slug_or_id)
                      end

          return unless stale?(news_item)

          presented_news_item = Api::V2::News::ItemPresenter.new(news_item)

          serializer = Api::V2::News::ItemSerializer.new(presented_news_item, include: %i[collections])

          render json: serializer.serializable_hash
        end

      private

        def per_page
          requested_page_size = params[:per_page].presence&.to_i

          if PAGE_SIZES.include? requested_page_size
            requested_page_size
          else
            DEFAULT_PAGE_SIZE
          end
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
