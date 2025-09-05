FactoryBot.define do
  factory :user_delta_preference, class: 'PublicUsers::DeltaPreferences' do
    association :user, factory: :public_user, strategy: :create
    commodity_code { '1234567890' }
  end
end
