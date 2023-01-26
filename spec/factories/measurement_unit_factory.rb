FactoryBot.define do
  sequence(:measurement_unit_code, LoopingSequence.lower_a_to_upper_z, &:value)

  factory :measurement_unit do
    transient do
      description { Forgery(:basic).text }
    end

    measurement_unit_code { generate(:measurement_unit_code) }
    validity_start_date { 3.years.ago.beginning_of_day }
    validity_end_date   { nil }

    trait :with_description do
      after(:create) do |measurement_unit, evaluator|
        create :measurement_unit_description,
                          measurement_unit_code: measurement_unit.measurement_unit_code,
                          description: evaluator.description
      end
    end
  end

  factory :measurement_unit_description do
    measurement_unit_code { generate(:measurement_unit_code) }
    description { Forgery(:basic).text }
  end
end
