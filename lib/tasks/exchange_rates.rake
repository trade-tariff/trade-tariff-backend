namespace :exchange_rates do
  desc 'Load CSV data into ExchangeRateCurrencyRate table'
  task recreate_currency_rates: %w[environment] do
    ExchangeRateCurrencyRate.db.transaction do
      ExchangeRateCurrencyRate.truncate
      ExchangeRateCurrencyRate.populate
      ExchangeRateCurrencyRate.populate(ExchangeRateCurrencyRate::SPOT_RATES_FILE)
    end
  end

  desc 'Load CSV data into ExchangeRateCurrency table'
  task recreate_currencys: %w[environment] do
    ExchangeRateCurrency.db.transaction do
      ExchangeRateCurrency.truncate
      ExchangeRateCurrency.populate
    end
  end

  desc 'Load CSV data into ExchangeRateCountry table'
  task recreate_countrys: %w[environment] do
    ExchangeRateCountry.db.transaction do
      ExchangeRateCountry.truncate
      ExchangeRateCountry.populate
    end
  end
end
