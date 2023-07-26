FactoryBot.define do
  factory :exchange_rate_exchange_rate_file, class: 'ExchangeRates::ExchangeRateFile' do
    sequence(:period_year) { 2023 }
    sequence(:period_month) { 6 }
    file_path { '/exchange_rates/csv/exrates-monthly-0623.csv' }
    format { 'csv' }
    file_size { 123 }
    publication_date { Date.new(2023, 7, 25) }
  end
end
