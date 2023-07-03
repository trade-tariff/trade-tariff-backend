FactoryBot.define do
  factory :exchange_rate_currency_rate do
    currency_code { 'AED' }
    validity_start_date { Date.new(2020, 1, 1) }
    validity_end_date { Date.new(2020, 1, 31) }
    rate { 4.8012 }

    trait :spot_rate do
      validity_start_date { Date.new(2022, 12, 31) }
      validity_end_date { nil }
      rate { 1.7816 }
      rate_type { 'spot' }
    end
  end
end
