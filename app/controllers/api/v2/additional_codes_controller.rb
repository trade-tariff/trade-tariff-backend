module Api
  module V2
    class AdditionalCodesController < ApiController
      before_action :find_additional_codes

      def search
        options = {}
        options[:include] = [:measures, 'measures.goods_nomenclature']
        render json: Api::V2::AdditionalCodes::AdditionalCodeSerializer.new(@additional_codes, options.merge(serialization_meta)).serializable_hash
      end

      private

      def find_additional_codes
        TimeMachine.now do
          @additional_codes = search_service.perform
        end
      end

      def search_service
        @search_service ||= AdditionalCodeSearchService.new(params, current_page, per_page)
      end

      def per_page
        5
      end

      def serialization_meta
        {
          meta: {
            pagination: {
              page: current_page,
              per_page:,
              total_count: search_service.pagination_record_count
            }
          }
        }
      end
    end
  end
end
