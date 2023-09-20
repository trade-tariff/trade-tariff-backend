module Api
  module V2
    module ExchangeRates
      class BaseController < ApiController
        private

        def valid_exchange_rate_type?(type_param)
          [ExchangeRateCurrencyRate::SCHEDULED_RATE_TYPE, ExchangeRateCurrencyRate::SPOT_RATE_TYPE, ExchangeRateCurrencyRate::AVERAGE_RATE_TYPE].include?(type_param)
        end

        def type
          type_param = filter_params[:type]
          type_param if valid_exchange_rate_type?(type_param)
        end

        def filter_params
          params.fetch(:filter, {}).permit(:type)
        end
      end
    end
  end
end
