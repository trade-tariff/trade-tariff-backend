module Api
  module V2
    class ExchangeRatesController < ExchangeRates::BaseController
      def show
        render json: serialized_exchange_rate_collection
      end

      private

      def serialized_exchange_rate_collection
        ExchangeRates::ExchangeRateCollectionSerializer.new(
          exchange_rate_collection,
          include: %i[exchange_rates exchange_rate_files],
        ).serializable_hash
      end

      def exchange_rate_collection
        ::ExchangeRates::ExchangeRateCollection.build(period_month, period_year, type)
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
    end
  end
end