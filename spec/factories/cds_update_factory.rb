FactoryBot.define do
  factory :cds_update, parent: :base_update, class: 'TariffSynchronizer::CdsUpdate' do
    issue_date { example_date }
    filename { 'tariff_dailyExtract_v1_20201004T235959.gzip' }
    update_type { 'TariffSynchronizer::CdsUpdate' }

    trait :applied do
      state { 'A' }
    end
  end
end
