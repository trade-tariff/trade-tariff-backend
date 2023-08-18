module Api
  module V2
    module ExchangeRates
      class ExchangeRatesListSerializer
        include JSONAPI::Serializer

        set_type :exchange_rates_list

        attributes :year, :month

        has_many :exchange_rate_files, serializer: Api::V2::ExchangeRates::ExchangeRateFileSerializer
        has_many :exchange_rates, serializer: Api::V2::ExchangeRates::ExchangeRateSerializer
      end
    end
  end
end
