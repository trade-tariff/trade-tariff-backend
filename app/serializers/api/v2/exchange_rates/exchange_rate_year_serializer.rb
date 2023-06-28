module Api
  module V2
    module ExchangeRates
      class ExchangeRateYearSerializer
        include JSONAPI::Serializer

        set_type :exchange_rate_year

        attributes :year
      end
    end
  end
end
