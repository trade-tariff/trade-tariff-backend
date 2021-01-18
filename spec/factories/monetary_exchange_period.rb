FactoryBot.define do
  sequence(:monetary_exchange_sid) { |n| n }

  factory :monetary_exchange_period do
    monetary_exchange_period_sid { generate(:monetary_exchange_sid) }
    parent_monetary_unit_code { 'EUR' }
    validity_start_date { Date.current.at_beginning_of_month }
    operation_date { validity_start_date - 4.days }

    trait :old do
      validity_start_date { Date.current.at_beginning_of_month - 6.years }
    end
  end
end
