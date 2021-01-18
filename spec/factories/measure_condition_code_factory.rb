FactoryBot.define do
  sequence(:condition_code, LoopingSequence.lower_a_to_upper_z, &:value)

  factory :measure_condition_code do
    condition_code { generate(:condition_code) }
    validity_start_date { Date.current.ago(3.years) }
    validity_end_date   { nil }

    trait :xml do
      validity_end_date { Date.current.ago(1.year) }
    end
  end

  factory :measure_condition_code_description do
    condition_code { generate(:condition_code) }
    description    { Forgery(:basic).text }

    trait :xml do
      language_id { 'EN' }
    end
  end
end
