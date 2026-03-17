FactoryBot.define do
  factory :apply do
    whodunnit { "user-#{SecureRandom.hex(4)}" }
  end
end
