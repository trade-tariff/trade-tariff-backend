module Api
  module V2
    module ExchangeRates
      class BaseController < ApiController
        before_action :validate_exchange_rate_type

        private

        def validate_exchange_rate_type
          raise NotImplementedError, type unless valid_exchange_rate_type?
        end

        def valid_exchange_rate_type?
          [
            ExchangeRateCurrencyRate::MONTHLY_RATE_TYPE,
            ExchangeRateCurrencyRate::SPOT_RATE_TYPE,
            ExchangeRateCurrencyRate::AVERAGE_RATE_TYPE,
          ].include?(type)
        end

        def type
          filter_params[:type]
        end

        def filter_params
          params.fetch(:filter, {}).permit(:type)
        end
      end
    end
  end
end
