FactoryBot.define do
  factory :rollback do
    date { Time.zone.today }
    reason { SecureRandom.hex }
    whodunnit { "user-#{SecureRandom.hex(4)}" }
  end
end
