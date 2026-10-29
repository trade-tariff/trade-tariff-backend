module Api
  module Internal
    class EvaluationSyntheticInputSetItemsController < InternalController
      DEFAULT_PER_PAGE = 100
      MAX_OFFSET = 1_000_000
      MAX_PER_PAGE = 250

      def index
        render json: serializer_class.new(
          paginated_dataset.all,
          is_collection: true,
          meta: pagination_meta,
        ).serializable_hash
      end

    private

      def paginated_dataset
        @paginated_dataset ||= filtered_dataset.order(:id).paginate(current_page, per_page)
      end

      def filtered_dataset
        filter_by_set(EvaluationSyntheticInputSetItem.dataset)
      end

      def filter_by_set(dataset)
        return dataset unless params.key?(:set_id)

        set_id = Integer(params[:set_id], exception: false)
        raise ActionController::BadRequest, 'set_id must be a number' unless set_id

        dataset.where(set_id:)
      end

      def current_page
        page = [Integer(params[:page] || 1), 1].max
        maximum_page = (MAX_OFFSET / per_page) + 1
        raise ActionController::BadRequest, "page and per_page cannot produce an offset greater than #{MAX_OFFSET}" if page > maximum_page

        page
      rescue ArgumentError, TypeError
        1
      end

      def per_page
        Integer(params[:per_page] || DEFAULT_PER_PAGE).clamp(1, MAX_PER_PAGE)
      rescue ArgumentError, TypeError
        DEFAULT_PER_PAGE
      end

      def pagination_meta
        {
          pagination: {
            page: current_page,
            per_page:,
            total_count: paginated_dataset.pagination_record_count,
          },
        }
      end

      def serializer_class
        Api::Internal::EvaluationSyntheticInputSetItemSerializer
      end
    end
  end
end
