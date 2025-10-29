FactoryBot.define do
  factory :subscription_target, class: 'PublicUsers::SubscriptionTarget' do
    user_subscriptions_uuid { create(:user_subscription).uuid }
    target_id { '123' }
    target_type { 'commodity' }
    created_at { Time.zone.now }
    updated_at { Time.zone.now }
  end
end
