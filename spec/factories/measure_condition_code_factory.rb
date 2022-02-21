FactoryBot.define do
  sequence(:condition_code, LoopingSequence.lower_a_to_upper_z, &:value)

  factory :measure_condition_code do
    transient do
      description { 'Presentation of a certificate/licence/document' }
    end

    condition_code { generate(:condition_code) }
    validity_start_date { 3.years.ago.beginning_of_day }
    validity_end_date   { nil }

    trait :xml do
      validity_end_date { 1.year.ago.beginning_of_day }
    end

    trait :with_description do
      after(:create) do |measure_condition_code, evaluator|
        create(
          :measure_condition_code_description,
          condition_code: measure_condition_code.condition_code,
          description: evaluator.description,
        )
      end
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
