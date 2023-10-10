class ExchangeRateCountryCurrency < Sequel::Model(:exchange_rate_countries_currencies)
  plugin :timestamps, update_on_create: true

  SPOT_RATE_CURRENCY_CODES = %w[AUD CAD DKK EUR HKD JPY NOK ZAR SEK CHF USD].freeze
end
