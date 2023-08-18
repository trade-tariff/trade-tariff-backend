require 'csv'

class ExchangeRateCountry < Sequel::Model
  COUNTRY_FILE = 'data/exchange_rates/territory.csv'.freeze

  alias_method :id, :country_code

  class << self
    def populate(src = COUNTRY_FILE)
      unrestrict_primary_key

      CSV.foreach(src, headers: true) do |row|
        currency_code = row[2]
        country = row[0]
        country_code = row[1]

        ExchangeRateCountry.create(currency_code:, country:, country_code:)
      end

      restrict_primary_key
    end
  end
end
