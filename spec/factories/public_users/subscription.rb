FactoryBot.define do
  factory :user_subscription, class: 'PublicUsers::Subscription' do
    user_id { create(:public_user).id }
    subscription_type_id { create(:subscription_type).id }
    active { true }
    email { true }
    metadata { { commodity_codes: %w[1234567890 1234567891 9999999999], measures: %w[1234567892], chapters: %w[01 99] } }
  end
end
