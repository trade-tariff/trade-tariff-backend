require 'csv'

class ExchangeRateCurrencyRate < Sequel::Model
  RATES_FILE = 'data/exchange_rates/all_rates.csv'.freeze

  class << self
    def populate(src = RATES_FILE)
      unrestrict_primary_key

      CSV.foreach(src) do |row|
        currency_code = row[0]
        validity_start_date = row[1]
        validity_end_date = row[2]
        rate = row[3]

        ExchangeRateCurrencyRate.create(currency_code:, validity_start_date:, validity_end_date:, rate:)
      end

      restrict_primary_key
    end
  end
end
