module Api
  module V2
    module ExchangeRates
      class ExchangeRateSerializer
        include JSONAPI::Serializer

        set_type :exchange_rate

        attributes :currency_description,
                   :currency_code,
                   :rate,
                   :validity_start_date,
                   :validity_end_date

        has_many :exchange_rate_countries, serializer: Api::V2::ExchangeRates::ExchangeRateCountrySerializer
      end
    end
  end
end
