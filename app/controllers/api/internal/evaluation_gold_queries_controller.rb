module Api
  module Internal
    class EvaluationGoldQueriesController < InternalController
      DEFAULT_PER_PAGE = 100
      MAX_OFFSET = 1_000_000
      MAX_PER_PAGE = 250
      MAX_SOURCE_IDS = MAX_PER_PAGE

      def index
        render json: serializer_class.new(
          paginated_dataset.all,
          is_collection: true,
          meta: pagination_meta,
        ).serializable_hash
      end

      def show
        id = Integer(params[:id], exception: false)
        raise Sequel::NoMatchingRow unless id

        render json: serializer_class.new(EvaluationGoldQuery.where(id:, active: true).first!).serializable_hash
      end

    private

      def paginated_dataset
        @paginated_dataset ||= filtered_dataset.order(:id).paginate(current_page, per_page)
      end

      def filtered_dataset
        dataset = EvaluationGoldQuery.where(active: true)
        dataset = dataset.where(persona: params[:persona]) if params[:persona].present?
        dataset = dataset.where(source_type: params[:source_type]) if params[:source_type].present?
        filter_by_source_ids(dataset)
      end

      def filter_by_source_ids(dataset)
        return dataset unless params.key?(:source_ids)

        source_ids = params[:source_ids].to_s.split(',').map(&:strip).compact_blank.uniq
        raise ActionController::BadRequest, 'source_ids must contain at least one id' if source_ids.empty?
        raise ActionController::BadRequest, "source_ids cannot contain more than #{MAX_SOURCE_IDS} ids" if source_ids.size > MAX_SOURCE_IDS

        dataset.where(source_id: source_ids)
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
        Api::Internal::EvaluationGoldQuerySerializer
      end
    end
  end
end
