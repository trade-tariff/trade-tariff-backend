module Api
  module V2
    class QuotasController < ApiController
      before_action :find_quotas

      def search
        options = {}
        options[:include] = [:quota_order_number, 'quota_order_number.geographical_areas', :measures, 'measures.geographical_area']
        render json: Api::V2::Quotas::Definition::QuotaDefinitionSerializer.new(@quotas, options.merge(serialization_meta)).serializable_hash
      end

      private

      def find_quotas
        TimeMachine.now do
          @quotas = search_service.perform
        end
      end

      def search_service
        @search_service ||= QuotaSearchService.new(params, current_page, per_page)
      end

      def per_page
        5
      end

      def serialization_meta
        {
          meta: {
            pagination: {
              page: current_page,
              per_page: per_page,
              total_count: search_service.pagination_record_count
            }
          }
        }
      end
    end
  end
end
