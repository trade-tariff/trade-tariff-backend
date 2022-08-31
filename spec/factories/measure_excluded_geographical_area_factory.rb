FactoryBot.define do
  factory :measure_excluded_geographical_area do
    measure_sid { generate(:measure_sid) }
    geographical_area_sid { generate(:geographical_area_sid) }
    excluded_geographical_area { Forgery(:basic).text(exactly: 2).upcase }

    trait :with_geographical_area do
      after(:create) do |measure_excluded_geographical_area, _evaluator|
        create(
          :geographical_area,
          geographical_area_id: measure_excluded_geographical_area.excluded_geographical_area,
          geographical_area_sid: measure_excluded_geographical_area.geographical_area_sid,
        )
      end
    end
  end
end
