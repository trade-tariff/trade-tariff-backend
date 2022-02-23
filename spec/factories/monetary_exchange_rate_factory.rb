FactoryBot.define do
  factory :monetary_exchange_rate do
    child_monetary_unit_code { 'GBP' }
    exchange_rate { Random.rand.to_d.truncate(9) }
    operation_date { Time.zone.today.at_beginning_of_month - 5.days }
    monetary_exchange_period
  end
end
