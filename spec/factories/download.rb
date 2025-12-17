FactoryBot.define do
  factory :download do
    user_id { generate(:user_id) }
  end
end
