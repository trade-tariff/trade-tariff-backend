FactoryBot.define do
  factory :exchange_rate, class: 'ExchangeRates::ExchangeRate' do
    month { 6 }
    year { 2023 }
    country { 'Abu Dhabi' }
    country_code { 'DH' }
    currency_description { 'Dirham' }
    currency_code { 'AED' }
    rate { 4.5409 }
    validity_start_date { '2023-06-01T00:00:00.000Z' }
    validity_end_date { '2023-06-31T23:59:59.999Z' }
  end
end
