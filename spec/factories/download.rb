FactoryBot.define do
  factory :download do
    whodunnit { "user-#{SecureRandom.hex(4)}" }
  end
end
