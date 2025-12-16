FactoryBot.define do
  factory :apply do
    user_id { generate(:user_id) }
  end
end
