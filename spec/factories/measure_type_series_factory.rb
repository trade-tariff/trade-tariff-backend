FactoryBot.define do
  sequence(:measure_type_series_id, LoopingSequence.lower_a_to_upper_z, &:value)

  factory :measure_type_series do
    measure_type_series_id   { generate(:measure_type_series_id) }
    validity_start_date      { Date.current.ago(3.years) }
    validity_end_date        { nil }

    trait :xml do
      measure_type_combination { 0 }
      validity_end_date        { Date.current.ago(1.year) }
    end
  end

  factory :measure_type_series_description do
    measure_type_series_id { generate(:measure_type_series_id) }
    description { Forgery(:basic).text }

    trait :xml do
      language_id { 'EN' }
    end
  end
end
