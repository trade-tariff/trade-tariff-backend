class ExchangeRateCountryCurrency < Sequel::Model(:exchange_rate_countries_currencies)
  plugin :timestamps, update_on_create: true
end
