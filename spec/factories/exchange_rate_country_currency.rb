FactoryBot.define do
  factory :exchange_rate_country_currency do
    country_code { 'AD' }
    currency_code { 'EUR' }
    country_description { 'Andorra' }
    currency_description { 'Euro' }
    validity_start_date { '2020-01-01' }
    validity_end_date { nil }
  end
end
