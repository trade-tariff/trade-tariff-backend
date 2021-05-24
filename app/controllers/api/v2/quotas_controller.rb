module Api
  module V2
    class QuotasController < ApiController
      def search
        render json: serializable_hash
      end

      private

      def serializable_hash
        Api::V2::Quotas::Definition::QuotaDefinitionSerializer.new(
          search_service.perform,
          options,
        ).serializable_hash
      end

      def search_service
        @search_service ||= QuotaSearchService.new(params, current_page, per_page)
      end

      def per_page
        5
      end

      def actual_date
        Date.parse([params['year'], params['month'], params['day']].join('-'))
      rescue DateError # empty date param means today
        Date.current
      end

      def options
        {
          include: [:quota_order_number, 'quota_order_number.geographical_areas', :measures, 'measures.geographical_area'],
          meta: {
            pagination: {
              page: current_page,
              per_page: per_page,
              total_count: search_service.pagination_record_count,
            },
          },
        }
      end
    end
  end
end
