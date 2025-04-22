FactoryBot.define do
  factory :user_subscription do
    user
    subscription_type
    active { true }
    email { true }
    created_at { Time.zone.now }
    updated_at { Time.zone.now }
  end
end
