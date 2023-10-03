module Api
  module V2
    module ExchangeRates
      class ExchangeRatePeriodSerializer
        include JSONAPI::Serializer

        set_type :exchange_rate_period

        attributes :month, :year, :has_exchange_rates

        has_many :files, serializer: Api::V2::ExchangeRates::ExchangeRateFileSerializer
      end
    end
  end
end
