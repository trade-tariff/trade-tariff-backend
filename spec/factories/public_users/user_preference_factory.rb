FactoryBot.define do
  factory :public_users_user_preference, class: 'PublicUsers::UserPreference' do
    user_id { create(:public_users_user).id }
    chapter_ids { '01 02' }
  end
end
