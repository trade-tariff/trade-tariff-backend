module Api
  module V2
    module News
      class ItemsController < ApiController
        PAGE_SIZES = [1, 10, 20].freeze
        DEFAULT_PAGE_SIZE = 20

        def index
          news_items_page = ::News::Item.for_service(params[:service])
                                   .for_target(params[:target])
                                   .for_year(params[:year])
                                   .for_collection(params[:collection_id])
                                   .for_today
                                   .descending
                                   .select { news_items[:id] }
                                   .paginate(current_page, per_page)

          # Why? you may ask - because #paginate ignores #eager
          news_items_with_collections = ::News::Item.eager(:collections)
                                                    .where(id: news_items_page.pluck(:id))
                                                    .descending
                                                    .all

          serializer = Api::V2::News::ItemSerializer.new(news_items_with_collections,
                                                         include: %i[collections],
                                                         meta: pagination_meta(news_items_page))

          render json: serializer.serializable_hash
        end

        def show
          news_item = if params[:id].present? && !/\A\d+\z/.match?(params[:id])
                        ::News::Item.for_today.where(slug: params[:id]).take
                      else
                        ::News::Item.for_today.with_pk!(params[:id])
                      end

          serializer = Api::V2::News::ItemSerializer.new(news_item, include: %i[collections])

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
