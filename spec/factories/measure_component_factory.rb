FactoryBot.define do
  factory :measure_component do
    transient do
      measure {}
    end

    measure_sid { measure.try(:measure_sid) || generate(:measure_sid) }
    duty_expression_id { Forgery(:basic).text(exactly: 2) }
    duty_amount { Forgery(:basic).number }
    monetary_unit_code { 'EUR' }
    measurement_unit_code { Forgery(:basic).text(exactly: 3) }
    measurement_unit_qualifier_code { generate(:measurement_unit_qualifier_code) }
  end

  trait :small_producers_quotient do
    measurement_unit_code { 'SPQ' }
    measurement_unit_qualifier_code {}
  end

  trait :ad_valorem do
    monetary_unit_code { nil }
    measurement_unit_code { nil }
  end

  trait :asvx do
    measurement_unit_code { 'ASV' }
    measurement_unit_qualifier_code { 'X' }
  end

  trait :with_measure_unit do
    measurement_unit_code { 'DTN' }

    after(:create) do |measure_component, _evaluator|
      create(:measurement_unit, :with_description, measurement_unit_code: measure_component.measurement_unit_code)
      create(:measurement_unit_abbreviation, measurement_unit_code: measure_component.measurement_unit_code)
    end
  end

  trait :with_duty_expression do
    after(:build) do |measure_component, _evaluator|
      create(
        :duty_expression,
        :with_description,
        duty_expression_id: measure_component.duty_expression_id,
      )
    end
  end

  trait :agricultural_meursing do
    duty_expression_id { '12' }
  end

  trait :sugar_meursing do
    duty_expression_id { '21' }
  end

  trait :flour_meursing do
    duty_expression_id { '27' }
  end
end
