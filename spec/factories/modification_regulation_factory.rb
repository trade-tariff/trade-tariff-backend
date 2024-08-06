FactoryBot.define do
  sequence(:modification_regulation_sid) { |n| n }

  factory :modification_regulation do
    modification_regulation_id   { generate(:sid) }
    modification_regulation_role { 4 }
    validity_start_date { 3.years.ago.beginning_of_day }
    validity_end_date   { nil }
    approved_flag { true }

    base_regulation do
      create(:base_regulation, created_at: Time.zone.now)
    end

    trait :approved do
      approved_flag { true }
    end

    trait :unapproved do
      approved_flag { false }
    end
  end
end
