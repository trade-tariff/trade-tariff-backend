FactoryBot.define do
  factory :base_update, class: 'TariffSynchronizer::BaseUpdate' do
    transient do
      example_date { Forgery(:date).date }
    end

    filename { Forgery(:basic).text }
    issue_date { example_date }
    state { 'P' }

    trait :applied do
      state { 'A' }
    end

    trait :pending do
      state { 'P' }
    end

    trait :failed do
      state { 'F' }
    end

    trait :missing do
      state { 'M' }
    end

    trait :applied_yesterday do
      applied
      issue_date { 2.days.ago.to_date }
      applied_at { 1.day.ago }
    end

    trait :applied_today do
      applied
      issue_date { 1.day.ago.to_date }
      applied_at { 10.minutes.ago }
    end

    trait :with_corresponding_data do
      applied

      after(:create) do |update, _evaluator|
        create(
          :measure,
          filename: update.filename,
          operation_date: update.issue_date,
        )
      end
    end
  end
end
