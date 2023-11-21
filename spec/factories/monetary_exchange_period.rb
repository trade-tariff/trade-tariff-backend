FactoryBot.define do
  sequence(:monetary_exchange_sid) { |n| n }

  factory :monetary_exchange_period do
    monetary_exchange_period_sid { generate(:monetary_exchange_sid) }
    parent_monetary_unit_code { 'EUR' }
    validity_start_date { Time.zone.today.at_beginning_of_month }
    operation_date { validity_start_date - 4.days }

    trait :six_years_old do
      validity_start_date { Time.zone.today.at_beginning_of_month - 6.years }
    end
  end
end
