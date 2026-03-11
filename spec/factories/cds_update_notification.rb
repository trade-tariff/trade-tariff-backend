FactoryBot.define do
  factory :cds_update_notification do
    filename { create(:cds_update).filename }
    whodunnit { "user-#{SecureRandom.hex(4)}" }
  end
end
