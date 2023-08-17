FactoryBot.define do
  factory :exchange_rate_currency_rate do
    currency_code { 'AED' }
    validity_start_date { Time.zone.today.next_month.beginning_of_month }
    validity_end_date { Time.zone.today.next_month.end_of_month }
    rate { 4.8012 }
    rate_type { 'scheduled' }

    trait :spot_rate do
      validity_start_date { Date.new(2022, 12, 31) }
      validity_end_date { nil }
      rate { 1.7816 }
      rate_type { 'spot' }
    end
  end
end
