FactoryBot.define do
  factory :public_user, class: 'PublicUsers::User' do
    external_id { SecureRandom.uuid }
  end
end
