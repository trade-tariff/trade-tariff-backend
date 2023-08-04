FactoryBot.define do
  sequence(:measure_condition_sid) { |n| n }
  sequence(:condition_measurement_unit_qualifier_code, LoopingSequence.lower_a_to_upper_z, &:value)
  sequence(:action_code, LoopingSequence.lower_a_to_upper_z, &:value)

  factory :measure_condition do
    transient do
      certificate {}
      measure {}
      measurement_unit_code {}
      measurement_unit_qualifier_code {}
      measure_condition_code { Forgery(:basic).text(exactly: 2) }
    end

    measure_condition_sid { generate(:measure_condition_sid) }
    measure_sid { measure.try(:measure_sid) || generate(:measure_sid) }
    condition_code { create(:measure_condition_code, :with_description, condition_code: measure_condition_code).condition_code }
    component_sequence_number { Forgery(:basic).number }
    condition_duty_amount { Forgery(:basic).number }
    condition_monetary_unit_code { Forgery(:basic).text(exactly: 3) }
    condition_measurement_unit_code { Forgery(:basic).text(exactly: 3) }
    certificate_code { certificate.try(:certificate_code) || Forgery(:basic).text(exactly: 3) }
    certificate_type_code { certificate.try(:certificate_type_code) || Forgery(:basic).text(exactly: 1) }
  end

  trait :with_measure_condition_components do
    transient do
      duty_expression_id { '01' }
    end

    after(:create) do |measure_condition, evaluator|
      create(
        :measure_condition_component,
        measure_condition_sid: measure_condition.measure_condition_sid,
        measurement_unit_code: evaluator.measurement_unit_code,
        measurement_unit_qualifier_code: evaluator.measurement_unit_qualifier_code,
        duty_expression_id: evaluator.duty_expression_id,
      )

      measure_condition.reload
    end
  end

  trait :threshold do
    condition_duty_amount { 3.50 }
    condition_monetary_unit_code {}
    condition_measurement_unit_code { 'DTN' }
    condition_measurement_unit_qualifier_code { 'R' }
    certificate_code {}
    certificate_type_code {}
  end

  trait :percentage_abv do
    condition_duty_amount { 3.50 }
    condition_monetary_unit_code {}
    condition_measurement_unit_code { 'ASV' }
    condition_measurement_unit_qualifier_code {}
    certificate_code {}
    certificate_type_code {}
  end

  trait :without_threshold do
    condition_duty_amount {}
    condition_monetary_unit_code {}
    condition_measurement_unit_code {}
    condition_measurement_unit_qualifier_code {}
    certificate_code {}
    certificate_type_code {}
  end

  trait :negative do
    action_code { '04' }
    condition_duty_amount {}
    condition_monetary_unit_code {}
    condition_measurement_unit_code {}
    condition_measurement_unit_qualifier_code {}
    certificate_code {}
    certificate_type_code {}

    after(:create) do |measure_condition, _evaluator|
      create(:measure_action, action_code: measure_condition.action_code)
    end
  end

  trait :exemption do
    condition_duty_amount {}
    condition_monetary_unit_code {}
    condition_measurement_unit_code {}
    condition_measurement_unit_qualifier_code {}
    certificate_code { '005' }
    certificate_type_code { 'Y' }
  end

  trait :document do
    condition_duty_amount {}
    condition_monetary_unit_code {}
    condition_measurement_unit_code {}
    condition_measurement_unit_qualifier_code {}
    certificate_code { '005' }
    certificate_type_code { 'D' }
  end

  trait :unknown do
    condition_duty_amount {}
    condition_monetary_unit_code {}
    condition_measurement_unit_code {}
    condition_measurement_unit_qualifier_code {}
    certificate_code {}
    certificate_type_code {}
  end

  trait :cds_waiver do
    condition_duty_amount {}
    condition_monetary_unit_code {}
    condition_measurement_unit_code {}
    condition_measurement_unit_qualifier_code {}
    certificate_code { '99L' }
    certificate_type_code { '9' }
  end

  trait :other_exemption do
    condition_duty_amount {}
    condition_monetary_unit_code {}
    condition_measurement_unit_code {}
    condition_measurement_unit_qualifier_code {}
    certificate_code { '084' }
    certificate_type_code { 'C' }
  end

  trait :with_guidance do
    after(:create) do |measure_condition, _evaluator|
      create(
        :appendix_5a,
        certificate_code: measure_condition.certificate_code,
        certificate_type_code: measure_condition.certificate_type_code,
      )
    end
  end

  trait :without_guidance do
  end

  trait :without_certificate do
    certificate_code {}
    certificate_type_code {}
  end

  trait :weight do
    threshold
    condition_measurement_unit_code { 'KGM' }
  end

  trait :volume do
    threshold
    condition_measurement_unit_code { 'LTR' }
  end

  trait :price do
    threshold
    condition_monetary_unit_code { 'EUR' }
  end

  trait :eps do
    weight
    price
    condition_code { 'V' }
  end
end
