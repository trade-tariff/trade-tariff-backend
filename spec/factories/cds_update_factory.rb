FactoryBot.define do
  sequence(:cds_update_time_suffix) { |n| sprintf('%06d', n) }

  factory :cds_update, parent: :base_update, class: 'TariffSynchronizer::CdsUpdate' do
    issue_date { example_date }

    filename do
      time_suffix = generate(:cds_update_time_suffix)
      "tariff_dailyExtract_v1_#{example_date.strftime('%Y%m%d')}T#{time_suffix}.gzip"
    end
    filesize { 10 } # below threshold for oplog inserts check

    update_type { 'TariffSynchronizer::CdsUpdate' }

    trait :pending do
      state { 'P' }
    end

    trait :applied do
      state { 'A' }
    end

    trait :failed do
      state { 'F' }
    end

    trait :with_measure do
      after :create do |cds_update, _evaluator|
        create :measure, operation_date: cds_update.issue_date, filename: cds_update.filename
      end
    end
  end
end
