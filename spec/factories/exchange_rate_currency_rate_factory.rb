FactoryBot.define do
  factory :exchange_rate_currency_rate do
    currency_code { 'AED' }
    validity_start_date { Time.zone.today.next_month.beginning_of_month }
    validity_end_date { validity_start_date.to_date.end_of_month }
    rate { 4.8012 }
    rate_type { 'monthly' }

    trait :with_usa do
      currency_code { 'USD' }

      after(:create) do |currency_rate|
        create(
          :exchange_rate_country_currency,
          currency_code: currency_rate.currency_code,
          country_code: 'US',
          country_description: 'United States',
          currency_description: 'Dollar',
          validity_start_date: currency_rate.validity_start_date,
          validity_end_date: currency_rate.validity_end_date,
        )
      end
    end

    trait :monthly_rate do
      rate_type { 'monthly' }
    end

    trait :spot_rate do
      rate_type { 'spot' }
      validity_start_date { Time.zone.today.end_of_month }
      validity_end_date { Time.zone.today.end_of_month }
    end

    trait :average_rate do
      rate_type { 'average' }
    end
  end
end
