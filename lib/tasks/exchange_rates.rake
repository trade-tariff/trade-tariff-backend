namespace :exchange_rates do
  desc 'Repopulate all exchange rate tables'
  task recreate: %w[recreate_currency_rates recreate_currencies recreate_countries]

  desc 'Load CSV data into ExchangeRateCurrencyRate table'
  task recreate_currency_rates: %w[environment] do
    ExchangeRateCurrencyRate.db.transaction do
      ExchangeRateCurrencyRate.truncate
      ExchangeRateCurrencyRate.populate
      ExchangeRateCurrencyRate.populate(ExchangeRateCurrencyRate::SPOT_RATES_FILE)
    end
  end

  desc 'Load CSV data into ExchangeRateCurrency table'
  task recreate_currencies: %w[environment] do
    ExchangeRateCurrency.db.transaction do
      ExchangeRateCurrency.truncate
      ExchangeRateCurrency.populate
    end
  end

  desc 'Load CSV data into ExchangeRateCountry table'
  task recreate_countries: %w[environment] do
    ExchangeRateCountry.db.transaction do
      ExchangeRateCountry.truncate
      ExchangeRateCountry.populate
    end
  end

  desc 'Import old data into files'
  task import_old_data: %w[environment] do
    ExchangeRate::CreateOldFilesService.call
  end
end
