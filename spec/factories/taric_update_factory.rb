FactoryBot.define do
  factory :taric_update, parent: :base_update, class: 'TariffSynchronizer::TaricUpdate' do
    transient do
      sequence_number { example_date.yday }
    end

    issue_date { example_date }

    # Example: 2015-04-15_TGB15072.xml
    filename { "#{example_date}_TGB#{example_date.strftime('%y')}#{sequence_number}.xml" }

    update_type { 'TariffSynchronizer::TaricUpdate' }

    trait :applied do
      state { 'A' }
    end

    trait :pending do
      state { 'P' }
    end
  end
end
