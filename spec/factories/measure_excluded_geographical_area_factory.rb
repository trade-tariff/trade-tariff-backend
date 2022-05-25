FactoryBot.define do
  factory :measure_excluded_geographical_area do
    measure_sid { generate(:measure_sid) }
    geographical_area_sid { generate(:geographical_area_sid) }
    excluded_geographical_area { Forgery(:basic).text(exactly: 2).upcase }
  end
end
