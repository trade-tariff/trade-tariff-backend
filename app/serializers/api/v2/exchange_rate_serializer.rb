module Api
  module V2
    class ExchangeRateSerializer
      include JSONAPI::Serializer

      set_type :exchange_rate

      attributes :id,
                 :rate,
                 :base_currency,
                 :applicable_date
    end
  end
end
