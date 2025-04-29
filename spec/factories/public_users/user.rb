FactoryBot.define do
  factory :public_user do
    external_id { SecureRandom.uuid }
    created_at { Time.zone.now }
    updated_at { Time.zone.now }
  end
end
