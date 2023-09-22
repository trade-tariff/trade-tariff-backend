FactoryBot.define do
  factory :exchange_rate_currency_rate do
    currency_code { 'AED' }
    validity_start_date { Time.zone.today.next_month.beginning_of_month }
    validity_end_date { validity_start_date.to_date.end_of_month }
    rate { 4.8012 }
    rate_type { 'scheduled' }

    trait :with_multiple_countries do
      after(:create) do |currency_rate|
        create(
          :exchange_rate_country,
          currency_code: currency_rate.currency_code,
          country_code: 'DH',
          country: 'Abu Dhabi',
        )
        create(
          :exchange_rate_country,
          currency_code: currency_rate.currency_code,
          country_code: 'DU',
          country: 'Dubai',
        )
      end
    end

    trait :with_usa do
      currency_code { 'USD' }

      after(:create) do |currency_rate|
        create(
          :exchange_rate_currency,
          currency_code: currency_rate.currency_code,
          currency_description: 'Dollar',
        )
        create(
          :exchange_rate_country,
          currency_code: currency_rate.currency_code,
          country_code: 'US',
          country: 'United States',
        )
      end
    end

    trait :scheduled_rate do
      rate_type { 'scheduled' }
    end

    trait :spot_rate do
      rate_type { 'spot' }
    end

    trait :average_rate do
      rate_type { 'average' }
    end
  end
end
