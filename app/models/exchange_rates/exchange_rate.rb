module ExchangeRates
  class ExchangeRate
    attr_accessor :year,
                  :month,
                  :country,
                  :country_code,
                  :currency_description,
                  :currency_code,
                  :rate,
                  :validity_start_date,
                  :validity_end_date

    def id
      "#{year}-#{month}-#{country_code}"
    end

    class << self
      def wrap(rates)
        rates.map do |exchange_rate|
          build(exchange_rate)
        end
      end

      def build(rate)
        exchange_rate = new
        exchange_rate.country = rate.country
        exchange_rate.country_code = rate.country_code
        exchange_rate.currency_description = rate.currency_description
        exchange_rate.currency_code = rate.currency_code
        exchange_rate.rate = rate.rate
        exchange_rate.validity_start_date = rate.validity_start_date
        exchange_rate.validity_end_date = rate.validity_end_date
        exchange_rate
      end
    end
  end
end
