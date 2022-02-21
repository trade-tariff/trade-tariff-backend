FactoryBot.define do
  factory :measurement do
    measurement_unit_code           { Forgery(:basic).text(exactly: 2) }
    measurement_unit_qualifier_code { generate(:measurement_unit_qualifier_code) }
    validity_start_date             { 3.years.ago.beginning_of_day }
    validity_end_date               { nil }

    trait :xml do
      validity_end_date { 1.year.ago.beginning_of_day }
    end
  end
end
