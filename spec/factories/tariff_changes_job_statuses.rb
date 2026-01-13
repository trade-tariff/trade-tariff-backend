FactoryBot.define do
  factory :tariff_changes_job_status do
    operation_date { Date.current }
    changes_generated_at { nil }
    emails_sent_at { nil }

    trait :with_changes_generated do
      changes_generated_at { Time.zone.now }
    end

    trait :with_emails_sent do
      changes_generated_at { Time.zone.now }
      emails_sent_at { Time.zone.now }
    end

    trait :pending_email do
      changes_generated_at { Time.zone.now }
      emails_sent_at { nil }
    end
  end
end
