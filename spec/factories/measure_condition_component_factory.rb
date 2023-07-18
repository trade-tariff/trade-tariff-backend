FactoryBot.define do
  sequence(:measure_condition_component) { |n| n }

  factory :measure_condition_component do
    transient do
      measure_condition {}
    end

    measure_condition_sid { measure_condition.try(:measure_condition_sid) || generate(:measure_condition_component) }
    duty_expression_id    { Forgery(:basic).text(exactly: 2) }
    duty_amount           { Forgery(:basic).number }
    monetary_unit_code    { Forgery(:basic).text(exactly: 3) }
    measurement_unit_code { Forgery(:basic).text(exactly: 3) }
    measurement_unit_qualifier_code { generate(:measurement_unit_qualifier_code) }

    trait :with_duty_expression do
      after(:create) do |measure_condition_component, _evaluator|
        create(:duty_expression, :with_description, duty_expression_id: measure_condition_component.duty_expression_id)
      end
    end
  end
end
