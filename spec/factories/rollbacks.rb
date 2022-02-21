FactoryBot.define do
  factory :rollback do
    date { Time.zone.today }
    reason { SecureRandom.hex }
    user_id { create(:user).id }
  end
end
