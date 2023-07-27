FactoryBot.define do
  factory :exchange_rate_file do
    sequence(:period_year) { 2023 }
    sequence(:period_month) { 6 }
    format { 'csv' }
    file_size { 123 }
    publication_date { Date.new(2023, 7, 25) }
  end
end
