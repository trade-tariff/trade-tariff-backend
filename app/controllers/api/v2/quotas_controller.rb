module Api
  module V2
    class QuotasController < ApiController
      DEFAULT_INCLUDES = %w[quota_order_number quota_order_number.geographical_areas measures measures.geographical_area].freeze

      def search
        render json: serialized_quota_definitions
      end

      private

      def serialized_quota_definitions
        Api::V2::Quotas::Definition::QuotaDefinitionSerializer.new(
          quotas, serializer_options
        ).serializable_hash
      end

      def quotas
        # TODO: We've added a filter that does not propagate to related resources (e.g. the definition validity time window). We need to make sure that the as_of functionality we've added propagates to related resources.
        TimeMachine.now do
          @quotas = search_service.perform
        end
      end

      def serializer_options
        {
          include: includes,
          meta: {
            pagination: {
              page: current_page,
              per_page: per_page,
              total_count: search_service.pagination_record_count,
            },
          },
        }
      end

      def search_service
        @search_service ||= QuotaSearchService.new(params, current_page, per_page)
      end

      def per_page
        5
      end

      def includes
        return provided_includes if provided_includes.present?

        DEFAULT_INCLUDES
      end

      def provided_includes
        include_params.presence || []
      end
    end
  end
end
