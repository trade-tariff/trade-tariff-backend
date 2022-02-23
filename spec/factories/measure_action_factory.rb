FactoryBot.define do
  factory :measure_action do
    action_code         { Forgery(:basic).text(exactly: 2) }
    validity_start_date { 3.years.ago.beginning_of_day }
    validity_end_date   { nil }

    trait :with_description do
      after(:create) do |measure_action, _evaluator|
        create(:measure_action_description, action_code: measure_action.action_code)
      end
    end
  end
end
