module Api
  module V2
    module ExchangeRates
      class ExchangeRateCountrySerializer
        include JSONAPI::Serializer

        set_type :exchange_rate_country

        attributes :currency_code,
                   :country_code,
                   :country
      end
    end
  end
end
