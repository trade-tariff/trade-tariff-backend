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
          quota_definitions, serializer_options
        ).serializable_hash
      end

      def quota_definitions
        search_service.call
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

      def actual_date
        Date.parse([params['year'], params['month'], params['day']].join('-'))
      rescue ArgumentError # empty date, default to as_of in ApplicationController
        super
      end
    end
  end
end
