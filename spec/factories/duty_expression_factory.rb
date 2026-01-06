FactoryBot.define do
  sequence(:duty_expression_description) { |n| n }

  factory :duty_expression do
    duty_expression_id  { generate(:duty_expression_description) }
    validity_start_date { '2020-12-31'.to_date.beginning_of_day }
    validity_end_date   { nil }

    trait :with_description do
      after(:create) do |duty_expression, _evaluator|
        create(:duty_expression_description, duty_expression_id: duty_expression.duty_expression_id)
      end
    end
  end

  factory :duty_expression_description do
    duty_expression_id  { generate(:duty_expression_description) }
    description         { Forgery(:basic).text }
  end
end
