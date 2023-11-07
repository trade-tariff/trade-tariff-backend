FactoryBot.define do
  factory :download do
    user_id { create(:user).id }
  end
end
