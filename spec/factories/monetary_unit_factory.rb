FactoryBot.define do
  factory :monetary_unit do
    monetary_unit_code { Forgery(:basic).text(exactly: 3) }
    validity_start_date { 3.years.ago.beginning_of_day }
    validity_end_date   { nil }

    trait :with_description do
      after(:create) do |monetary_unit, _evaluator|
        FactoryBot.create :monetary_unit_description, monetary_unit_code: monetary_unit.monetary_unit_code
      end
    end
  end

  factory :monetary_unit_description do
    monetary_unit_code { Forgery(:basic).text(exactly: 3) }
    description        { Forgery(:basic).text }
  end
end
