FactoryBot.define do
  factory :measure_component do
    measure_sid { generate(:measure_sid) }
    duty_expression_id { Forgery(:basic).text(exactly: 2) }
    duty_amount { Forgery(:basic).number }
    monetary_unit_code { Forgery(:basic).text(exactly: 3) }
    measurement_unit_code { Forgery(:basic).text(exactly: 3) }
    measurement_unit_qualifier_code { generate(:measurement_unit_qualifier_code) }
  end

  trait :ad_valorem do
    monetary_unit_code { nil }
    measurement_unit_code { nil }
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
