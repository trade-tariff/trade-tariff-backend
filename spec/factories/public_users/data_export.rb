FactoryBot.define do
  factory :data_export, class: 'PublicUsers::DataExport' do
    id { '123' }
    user_subscription { create(:user_subscription) }
    export_type { PublicUsers::DataExport::CCWL }
    status { PublicUsers::DataExport::QUEUED }
  end
end
