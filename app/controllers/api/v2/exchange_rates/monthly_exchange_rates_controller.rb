module Api
  module V2
    module ExchangeRates
      class MonthlyExchangeRatesController < ApiController
        def show
          render json: serialized_monthly_exchange_rate
        end

        private

        def serialized_monthly_exchange_rate
          ExchangeRates::MonthlyExchangeRateSerializer.new(
            monthly_exchange_rate,
            include: %i[exchange_rates exchange_rate_files],
          ).serializable_hash
        end

        def monthly_exchange_rate
          ::ExchangeRates::MonthlyExchangeRate.build(period_month, period_year, type)
        end

        def period_month
          id.split('-').last
        end

        def period_year
          id.split('-').first
        end

        def id
          params[:id].to_s
        end

        def filter_params
          params.fetch(:filter, {}).permit(:type)
        end

        def type
          filter_params[:type]
        end

        def type
          type_param = filter_params[:type]

          type_param if [ExchangeRateCurrencyRate::SCHEDULED_RATE_TYPE, ExchangeRateCurrencyRate::SPOT_RATE_TYPE, ExchangeRateCurrencyRate::AVERAGE_RATE_TYPE].include?(type_param)
        end
      end
    end
  end
end
