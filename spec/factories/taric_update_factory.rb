FactoryBot.define do
  factory :taric_update, parent: :base_update, class: 'TariffSynchronizer::TaricUpdate' do
    transient do
      sequence_number { example_date.yday }
    end

    # TODO: try to remove example_date and use issue_date
    issue_date { example_date }

    # Example: 2015-04-15_TGB15072.xml
    filename { "#{example_date.iso8601}_TGB#{example_date.strftime('%y')}#{sequence_number.to_s.rjust(3, '0')}.xml" }

    update_type { 'TariffSynchronizer::TaricUpdate' }

    trait :applied do
      state { 'A' }
    end

    trait :pending do
      state { 'P' }
    end

    trait :failed do
      state { 'F' }
    end
  end
end
