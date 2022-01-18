FactoryBot.define do
  factory :cds_update, parent: :base_update, class: 'TariffSynchronizer::CdsUpdate' do
    issue_date { example_date }

    filename { "tariff_dailyExtract_v1_#{example_date.strftime('%Y%m%d')}T235959.gzip" }

    update_type { 'TariffSynchronizer::CdsUpdate' }

    trait :pending do
      state { 'P' }
    end

    trait :applied do
      state { 'A' }
    end
  end
end
