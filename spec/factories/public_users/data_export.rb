FactoryBot.define do
  factory :data_export, class: 'PublicUsers::DataExport' do
    id { '123' }
    user { create(:public_user) }
    export_type { PublicUsers::DataExport::CCWL }
    status { PublicUsers::DataExport::QUEUED }
  end
end
