require 'csv'

class ExchangeRateCurrency < Sequel::Model
  CURRENCY_FILE = 'data/exchange_rates/currency.csv'.freeze

  class << self
    def populate(src = CURRENCY_FILE)
      unrestrict_primary_key

      CSV.foreach(src, headers: true) do |row|
        currency_code = row[0]
        currency_description = row[1]
        spot_rate_required = row[2]&.downcase == 'true'

        ExchangeRateCurrency.create(currency_code:, currency_description:, spot_rate_required:)
      end

      restrict_primary_key
    end
  end
end
