module Api
  module V2
    module ExchangeRates
      class PeriodListsController < ApiController
        def show
          render json: serialized_period_list
        end

        private

        def serialized_period_list
          ExchangeRates::ExchangeRatePeriodListSerializer.new(
            period_list,
            include: %i[exchange_rate_periods exchange_rate_years],
          ).serializable_hash
        end

        def period_list
          @period_list ||= ::ExchangeRates::PeriodList.build(year)
        end

        def year
          (params[:year].presence || ExchangeRateCurrencyRate.max_year).to_i
        end
      end
    end
  end
end
