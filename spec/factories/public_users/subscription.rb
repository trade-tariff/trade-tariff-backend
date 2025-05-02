FactoryBot.define do
  factory :user_subscription, class: 'PublicUsers::Subscription' do
    user factory: :public_user
    subscription_type factory: :subscription_type
    active { true }
    email { true }
  end
end