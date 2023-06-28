require 'csv'

class ExchangeRateCurrencyRate < Sequel::Model
  RATES_FILE = 'data/exchange_rates/all_rates.csv'.freeze
  SPOT_RATES_FILE = 'data/exchange_rates/all_spot_rates.csv'.freeze

  def scheduled_rate?
    validity_end_date.present? && validity_start_date.day == 1 && validity_end_date == validity_start_date.end_of_month
  end

  def spot_rate?
    [3, 12].include?(validity_start_date.month) && validity_start_date.day == 31 && validity_end_date.nil?
  end

  class << self
    def populate(src = RATES_FILE)
      unrestrict_primary_key

      CSV.foreach(src) do |row|
        currency_code = row[0]
        validity_start_date = row[1]
        validity_end_date = row[2]
        rate = row[3]

        exchange_rate_currency_rate = new(currency_code:, validity_start_date:, validity_end_date:, rate:)
        exchange_rate_currency_rate.rate_type = determine_rate_type(exchange_rate_currency_rate)
        exchange_rate_currency_rate.save
      end

      restrict_primary_key
    end

    private

    def determine_rate_type(rate)
      return if rate.validity_start_date.blank?
      return 'scheduled' if rate.scheduled_rate?
      return 'spot' if rate.spot_rate?
    end
  end
end
