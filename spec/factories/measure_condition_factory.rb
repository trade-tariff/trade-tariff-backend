FactoryBot.define do
  sequence(:measure_condition_sid) { |n| n }

  factory :measure_condition do
    transient do
      measurement_unit_code {}
    end

    measure_condition_sid { generate(:measure_condition_sid) }
    measure_sid { generate(:measure_sid) }
    condition_code { Forgery(:basic).text(exactly: 2) }
    component_sequence_number { Forgery(:basic).number }
    condition_duty_amount { Forgery(:basic).number }
    condition_monetary_unit_code { Forgery(:basic).text(exactly: 3) }
    condition_measurement_unit_code { Forgery(:basic).text(exactly: 3) }
    sequence(:condition_measurement_unit_qualifier_code, LoopingSequence.lower_a_to_upper_z, &:value)
    sequence(:action_code, LoopingSequence.lower_a_to_upper_z, &:value)
    sequence(:certificate_type_code, LoopingSequence.lower_a_to_upper_z, &:value)
    certificate_code { Forgery(:basic).text(exactly: 3) }
  end

  trait :with_measure_condition_components do
    after(:create) do |measure_condition, evaluator|
      create(
        :measure_condition_component,
        measure_condition_sid: measure_condition.measure_condition_sid,
        measurement_unit_code: evaluator.measurement_unit_code,
      )

      measure_condition.reload
    end
  end
end
