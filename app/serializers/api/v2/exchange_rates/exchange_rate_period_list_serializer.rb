module Api
  module V2
    module ExchangeRates
      class ExchangeRatePeriodListSerializer
        include JSONAPI::Serializer

        set_type :exchange_rate_period_list

        attributes :year

        has_many :exchange_rate_periods, serializer: Api::V2::ExchangeRates::ExchangeRatePeriodSerializer
        has_many :exchange_rate_years, serializer: Api::V2::ExchangeRates::ExchangeRateYearSerializer
      end
    end
  end
end
