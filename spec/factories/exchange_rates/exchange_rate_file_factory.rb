FactoryBot.define do
  factory :exchange_rate_file, class: 'ExchangeRates::ExchangeRateFile' do
    file_path { '/exchange_rates/csv/exrates-monthly-0623.csv' }
    file_size { 1770 }
    format { 'csv' }
  end
end
