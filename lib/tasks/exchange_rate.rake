namespace :exchange_rate do
  desc 'insert day zero countries'
  task reindex: %w[environment] do
    ExchangeRates::CountryHistories::CreateDayZero.call('data/exchange_rates/day_zero_country_history.csv')
  end
end
