module Api
  module V2
    class ExchangeRatesController < ApiController
      def index
        render json: Api::V2::ExchangeRateSerializer.new(exchange_rates).serializable_hash
      end

      def exchange_rates
        ExchangeRate.build_collection
      end
    end
  end
end
