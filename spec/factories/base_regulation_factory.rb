FactoryBot.define do
  sequence(:base_regulation_sid) { |n| n }

  factory :base_regulation do
    base_regulation_id   { generate(:sid) }
    base_regulation_role { 1 }
    validity_start_date { Date.current.ago(3.years) }
    validity_end_date   { nil }
    effective_end_date  { nil }

    trait :abrogated do
      after(:build) do |br, _evaluator|
        FactoryBot.create(:complete_abrogation_regulation, complete_abrogation_regulation_id: br.base_regulation_id,
                                                           complete_abrogation_regulation_role: br.base_regulation_role)
      end
    end
  end
end
