module Api
  module V2
    module ExchangeRates
      class MonthlyExchangeRateSerializer
        include JSONAPI::Serializer

        set_type :monthly_exchange_rate

        attributes :year, :month

        has_many :exchange_rate_files, serializer: Api::V2::ExchangeRates::ExchangeRateFileSerializer
        has_many :exchange_rates, serializer: Api::V2::ExchangeRates::ExchangeRateSerializer
      end
    end
  end
end
