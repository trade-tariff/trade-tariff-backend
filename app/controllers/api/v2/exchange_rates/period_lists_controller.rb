module Api
  module V2
    module ExchangeRates
      class PeriodListsController < BaseController
        def show
          if serialized_period_list[:data].empty?
            render json: { data: {} }, status: :not_found
          else
            render json: serialized_period_list
          end
        end

        private

        def serialized_period_list
          ExchangeRates::ExchangeRatePeriodListSerializer.new(
            period_list,
            include: %i[exchange_rate_periods exchange_rate_years exchange_rate_periods.files],
          ).serializable_hash
        end

        def period_list
          @period_list ||= ::ExchangeRates::PeriodList.build(type, year)
        end

        def year
          params[:year]
        end
      end
    end
  end
end
