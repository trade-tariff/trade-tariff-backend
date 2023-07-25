module Api
  module V2
    module ExchangeRates
      class MonthlyExchangeRatesController < ApiController
        def show
          render json: serialized_exchange_rates_list
        end

        private

        def serialized_exchange_rates_list
          ExchangeRates::ExchangeRatesListSerializer.new(
            exchange_rates,
            include: %i[exchange_rate],
          ).serializable_hash
        end

        def exchange_rates
          @exchange_rates ||= ::ExchangeRates::RatesList.build(month, year)
        end

        def month
          (params[:month].presence || ExchangeRateCurrencyRate.max_month).to_i
        end

        def year
          (params[:year].presence || ExchangeRateCurrencyRate.max_year).to_i
        end
      end
    end
  end
end
