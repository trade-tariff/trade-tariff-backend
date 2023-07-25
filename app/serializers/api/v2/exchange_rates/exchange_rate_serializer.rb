module Api
  module V2
    module ExchangeRates
      class ExchangeRateSerializer
        include JSONAPI::Serializer

        set_type :exchange_rate

        attributes :country,
                   :country_code,
                   :currency_description,
                   :currency_code,
                   :rate,
                   :validity_start_date,
                   :validity_end_date
      end
    end
  end
end
