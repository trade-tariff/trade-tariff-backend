FactoryBot.define do
  factory :user_subscription, class: 'PublicUsers::Subscription' do
    user_id { create(:public_user).id }
    subscription_type_id { create(:subscription_type).id }
    active { true }
    email { true }
  end
end
