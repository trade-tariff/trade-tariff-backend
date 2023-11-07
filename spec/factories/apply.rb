FactoryBot.define do
  factory :apply do
    user_id { create(:user).id }
  end
end
