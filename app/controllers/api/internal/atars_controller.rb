module Api
  module Internal
    class AtarsController < InternalController
      DEFAULT_PER_PAGE = 100
      MAX_OFFSET = 1_000_000
      MAX_PER_PAGE = 250
      MAX_REFERENCES = MAX_PER_PAGE
      RESOURCE_COLUMNS = %i[
        ref
        commodity_code
        goods_nomenclature_item_id
        description
        justification
        keywords
        validity_start_date
        validity_end_date
        source_url
        fetched_at
        updated_at
      ].freeze

      def index
        render json: serializer_class.new(
          paginated_dataset.all,
          is_collection: true,
          meta: pagination_meta,
        ).serializable_hash
      end

      def show
        ruling = source_dataset.by_ref(params[:ref]).first!

        render json: serializer_class.new(ruling).serializable_hash
      end

    private

      def paginated_dataset
        @paginated_dataset ||= filtered_dataset.order(:ref).paginate(current_page, per_page)
      end

      def filtered_dataset
        return source_dataset unless params.key?(:refs)

        references = params[:refs].to_s.split(',').map(&:strip).compact_blank
        raise ActionController::BadRequest, 'refs must contain at least one reference' if references.empty?
        raise ActionController::BadRequest, "refs cannot contain more than #{MAX_REFERENCES} references" if references.size > MAX_REFERENCES

        source_dataset.where(ref: references.uniq)
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
        Api::Internal::AtarSerializer
      end

      def source_dataset
        TariffKnowledge::PublicAtarRuling.select(*RESOURCE_COLUMNS)
      end
    end
  end
end
