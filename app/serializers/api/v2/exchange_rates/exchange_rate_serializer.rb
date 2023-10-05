module Api
  module V2
    module ExchangeRates
      class ExchangeRateSerializer
        include JSONAPI::Serializer

        set_type :exchange_rate

        attributes :currency_description,
                   :currency_code,
                   :country_code,
                   :validity_start_date,
                   :validity_end_date

        attribute :country, &:country_description

        attribute :rate, &:presented_rate
      end
    end
  end
end
