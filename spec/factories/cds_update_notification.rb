FactoryBot.define do
  factory :cds_update_notification do
    filename { create(:cds_update).filename }
    user_id { create(:user).id }
  end
end
