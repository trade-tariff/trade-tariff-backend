FactoryBot.define do
  factory :exchange_rate_country do
    currency_code { 'AED' }
    country { 'Abu Dhabi' }
    country_code { 'DH' }
    active { nil }
  end
end
