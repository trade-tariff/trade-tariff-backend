module Api
  module V2
    module ExchangeRates
      class ExchangeRatePeriodSerializer
        include JSONAPI::Serializer

        set_type :exchange_rate_period

        attributes :month, :year
      end
    end
  end
end
