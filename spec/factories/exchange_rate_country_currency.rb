FactoryBot.define do
  factory :exchange_rate_country_currency do
    country_code { 'AD' }
    currency_code { 'EUR' }
    country_description { 'Andorra' }
    currency_description { 'Euro' }
    validity_start_date { '2020-01-01' }
    validity_end_date { nil }

    trait :us do
      country_code { 'US' }
      currency_code { 'USD' }
      country_description { 'United States' }
      currency_description { 'Dollar' }
    end

    trait :eu do
      country_code { 'EU' }
      currency_code { 'EUR' }
      country_description { 'Eurozone' }
      currency_description { 'Euro' }
    end

    trait :au do
      country_code { 'AU' }
      currency_code { 'AUD' }
      country_description { 'Australia' }
      currency_description { 'Dollar' }
    end

    trait :du do
      country_code { 'DU' }
      currency_code { 'AED' }
      country_description { 'Dubai' }
      currency_description { 'Dirham' }
    end

    trait :kz do
      country_code { 'KZ' }
      currency_code { 'KZT' }
      country_description { 'Kazakhstan' }
      currency_description { 'Tenge' }
    end

    trait :dh do
      country_code { 'DH' }
      currency_code { 'AED' }
      country_description { 'Abu Dhabi' }
      currency_description { 'Dirham' }
    end
  end
end
