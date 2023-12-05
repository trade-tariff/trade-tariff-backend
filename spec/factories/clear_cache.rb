FactoryBot.define do
  factory :clear_cache do
    user_id { create(:user).id }
  end
end
