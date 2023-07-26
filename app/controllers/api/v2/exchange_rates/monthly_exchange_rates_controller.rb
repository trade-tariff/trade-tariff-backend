module Api
  module V2
    module ExchangeRates
      class MonthlyExchangeRatesController < ApiController
        def show
          if month && year
            render json: serialized_exchange_rates_list
          else
            render json: { "errors": [{ "detail": 'not found' }] }, status: :not_found
          end
        end

        private

        def serialized_exchange_rates_list
          ExchangeRates::ExchangeRatesListSerializer.new(
            exchange_rates,
            include: %i[exchange_rates exchange_rate_files],
          ).serializable_hash
        end

        def exchange_rates
          @exchange_rates ||= ::ExchangeRates::RatesList.build(month, year)
        end

        def month
          return if params[:month].nil?

          params[:month].presence.to_i
        end

        def year
          return if params[:year].nil?

          params[:year].presence.to_i
        end
      end
    end
  end
end
