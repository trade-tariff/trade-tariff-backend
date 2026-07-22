module Api
  module V2
    module Quotas
      class UtilizationSummaryController < ApiController
        def index
          render json: Api::V2::Quotas::UtilizationSummarySerializer.new(
            portfolio,
            meta: response_meta,
          ).serializable_hash
        end

      private

        def portfolio
          @portfolio ||= portfolio_service.call
        end

        def portfolio_service
          @portfolio_service ||= QuotaPortfolioService.new(
            filters: filter_params,
            page: current_page,
            per_page:,
          )
        end

        def filter_params
          params.fetch(:filter, {}).permit(
            :measurement_unit_code,
            :quota_type,
          ).to_h.with_indifferent_access
        end

        def response_meta
          {
            pagination: {
              page: current_page,
              per_page:,
              total_count: portfolio_service.record_count,
            },
          }
        end

        def per_page
          Integer(params[:per_page] || 25).clamp(1, QuotaPortfolioService::MAX_PER_PAGE)
        rescue ArgumentError
          25
        end
      end
    end
  end
end
