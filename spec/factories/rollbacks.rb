FactoryBot.define do
  factory :rollback do
    date { Time.zone.today }
    reason { SecureRandom.hex }
    user_id { generate(:user_id) }
  end
end
