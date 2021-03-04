FactoryBot.define do
  factory :measure_component do
    measure_sid { generate(:measure_sid) }
    duty_expression_id { Forgery(:basic).text(exactly: 2) }
    duty_amount { Forgery(:basic).number }
    monetary_unit_code { Forgery(:basic).text(exactly: 3) }
    measurement_unit_code { Forgery(:basic).text(exactly: 3) }
    measurement_unit_qualifier_code { generate(:measurement_unit_qualifier_code) }
  end

  trait :ad_valorum do
    monetary_unit_code { nil }
    measurement_unit_code { nil }
    duty_expression_id { DutyExpression::AD_VALORUM_DUTY_EXPRESSION_ID }
  end
end
