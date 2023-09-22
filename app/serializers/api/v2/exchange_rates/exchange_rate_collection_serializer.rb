module Api
  module V2
    module ExchangeRates
      class ExchangeRateCollectionSerializer
        include JSONAPI::Serializer

        set_type :exchange_rate_collection

        attributes :year, :month, :type

        has_many :exchange_rate_files, serializer: Api::V2::ExchangeRates::ExchangeRateFileSerializer
        has_many :exchange_rates, serializer: Api::V2::ExchangeRates::ExchangeRateSerializer
      end
    end
  end
end
