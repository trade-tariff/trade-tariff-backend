FactoryBot.define do
  sequence(:quota_order_number_sid) { |n| n }
  sequence(:quota_order_number_id) do
    "09#{Forgery(:basic).number(at_least: 5000, at_most: 9999)}"
  end

  factory :quota_association do
    main_quota_definition_sid  { Forgery(:basic).number }
    sub_quota_definition_sid   { Forgery(:basic).number }
    relation_type              { Forgery(:basic).text(exactly: 2) }
    coefficient                { Forgery(:basic).number }
  end

  factory :quota_order_number do
    transient do
      quota_definition_sid { generate(:sid) }
      quota_definition_validity_end_date { nil }
    end

    quota_order_number_sid { generate(:quota_order_number_sid) }
    quota_order_number_id  { generate(:quota_order_number_id) }
    validity_start_date { 4.years.ago.beginning_of_day }
    validity_end_date   { nil }

    trait :xml do
      validity_end_date { 1.year.ago.beginning_of_day }
    end

    trait :current do
      validity_end_date { nil }
    end

    trait :expired do
      validity_end_date { Time.zone.yesterday }
    end

    trait :current_definition do
      quota_definition_validity_end_date { nil }
    end

    trait :expired_definition do
      quota_definition_validity_end_date { Time.zone.yesterday }
    end

    trait :with_quota_definition do
      transient do
        quota_balance_events { false }
      end

      after(:create) do |quota_order_number, evaluator|
        attributes = {
          quota_order_number_id: quota_order_number.quota_order_number_id,
          quota_order_number_sid: quota_order_number.quota_order_number_sid,
          quota_definition_sid: evaluator.quota_definition_sid,
          validity_end_date: evaluator.quota_definition_validity_end_date,
        }
        if evaluator.quota_balance_events
          create(:quota_definition, :with_quota_balance_events, attributes)
        else
          create(:quota_definition, attributes)
        end
      end
    end
  end

  factory :quota_order_number_origin do
    transient do
      geographical_area {}
    end
    quota_order_number_origin_sid  { generate(:sid) }
    quota_order_number_sid         { generate(:sid) }

    geographical_area_id do
      geographical_area&.geographical_area_id || Forgery(:basic).text(exactly: 2)
    end

    geographical_area_sid do
      geographical_area&.geographical_area_sid || generate(:sid)
    end

    validity_start_date            { 4.years.ago.beginning_of_day }
    validity_end_date              { nil }

    trait :xml do
      validity_end_date { 1.year.ago.beginning_of_day }
    end

    trait :with_geographical_area do
      after(:build) do |qon|
        geographical_area = create(:geographical_area)
        qon.geographical_area_id = geographical_area.geographical_area_id
        qon.geographical_area_sid = geographical_area.geographical_area_sid
      end
    end
  end

  factory :quota_order_number_origin_exclusion do
    quota_order_number_origin_sid { generate(:sid) }

    after(:build) do |exclusion|
      if exclusion.excluded_geographical_area_sid.blank?
        geographical_area = create(:geographical_area)
        exclusion.excluded_geographical_area_sid = geographical_area.geographical_area_sid
      end
    end
  end

  factory :quota_reopening_event do
    quota_definition_sid  { generate(:sid) }
    occurrence_timestamp  { 24.hours.ago }
    reopening_date        { 1.year.ago.beginning_of_day }
  end

  factory :quota_definition do
    quota_definition_sid            { generate(:quota_order_number_sid) }
    quota_order_number_sid          { generate(:quota_order_number_sid) }
    quota_order_number_id           { generate(:quota_order_number_id) }
    monetary_unit_code              { Forgery(:basic).text(exactly: 3) }
    measurement_unit_code           { Forgery(:basic).text(exactly: 3) }
    measurement_unit_qualifier_code { generate(:measurement_unit_qualifier_code) }
    validity_start_date             { 4.years.ago.beginning_of_day }
    validity_end_date               { nil }
    critical_state                  { 'N' }
    critical_threshold              { Forgery(:basic).number }

    trait :actual do
      validity_start_date { 3.years.ago.beginning_of_day }
      validity_end_date   { nil }
    end

    trait :licensed do
      quota_order_number_id { '094111' }
    end

    trait :first_come_first_served do
      quota_order_number_id { '058002' }
    end

    trait :with_quota_balance_and_active_critical_events do
      transient { event_new_balance { 100 } }

      after(:create) do |quota_definition, evaluator|
        create(:quota_balance_event, quota_definition:, new_balance: evaluator.event_new_balance, occurrence_timestamp: Time.zone.today)
        create(:quota_critical_event, :active, quota_definition:, occurrence_timestamp: Time.zone.yesterday)
      end
    end

    trait :with_quota_balance_and_inactive_critical_events do
      transient { event_new_balance { 100 } }

      after(:create) do |quota_definition, evaluator|
        create(:quota_balance_event, quota_definition:, new_balance: evaluator.event_new_balance, occurrence_timestamp: Time.zone.today)
        create(:quota_critical_event, :inactive, quota_definition:, occurrence_timestamp: Time.zone.yesterday)
      end
    end

    trait :with_incoming_quota_closed_and_transferred_event do
      transient { closing_date { Time.zone.today } }

      after(:create) do |quota_definition, evaluator|
        create(
          :quota_closed_and_transferred_event,
          target_quota_definition_sid: quota_definition.quota_definition_sid,
          closing_date: evaluator.closing_date,
        )
      end
    end

    trait :with_quota_balance_events do
      transient { event_new_balance { 100 } }

      after(:create) do |quota_definition, evaluator|
        create(:quota_balance_event, quota_definition:, new_balance: evaluator.event_new_balance)
      end
    end

    trait :with_quota_critical_events do
      after(:create) do |quota_definition, _evaluator|
        create(:quota_critical_event, quota_definition:)
      end
    end

    trait :with_quota_exhaustion_events do
      after(:create) do |quota_definition, _evaluator|
        create(:quota_exhaustion_event, quota_definition:)
      end
    end

    trait :with_quota_unsuspension_events do
      after(:create) do |quota_definition, _evaluator|
        create(:quota_unsuspension_event, quota_definition:)
      end
    end

    trait :with_quota_reopening_events do
      after(:create) do |quota_definition, _evaluator|
        create(:quota_reopening_event, quota_definition:)
      end
    end

    trait :with_quota_unblocking_events do
      after(:create) do |quota_definition, _evaluator|
        create(:quota_unblocking_event, quota_definition:)
      end
    end

    trait :xml do
      validity_start_date             { 3.years.ago.beginning_of_day }
      validity_end_date               { 1.year.ago.beginning_of_day }
      volume                          { Forgery(:basic).number }
      initial_volume                  { Forgery(:basic).number }
      measurement_unit_code           { Forgery(:basic).text(exactly: 2) }
      maximum_precision               { Forgery(:basic).number }
      critical_state                  { Forgery(:basic).text(exactly: 2) }
      critical_threshold              { Forgery(:basic).number }
      monetary_unit_code              { Forgery(:basic).text(exactly: 2) }
      measurement_unit_qualifier_code { generate(:measurement_unit_qualifier_code) }
      description                     { Forgery(:lorem_ipsum).sentence }
    end
  end

  factory :quota_balance_event do
    quota_definition
    last_import_date_in_allocation { Time.zone.now }
    old_balance { Forgery(:basic).number }
    new_balance { Forgery(:basic).number }
    imported_amount { Forgery(:basic).number }
    occurrence_timestamp { 24.hours.ago }
  end

  factory :quota_blocking_period do
    quota_blocking_period_sid  { Forgery(:basic).number }
    quota_definition_sid       { Forgery(:basic).number }
    blocking_start_date        { 1.year.ago.beginning_of_day }
    blocking_end_date          { 1.year.ago.beginning_of_day }
    blocking_period_type       { Forgery(:basic).number }
    description                { Forgery(:lorem_ipsum).sentence }
  end

  factory :quota_closed_and_transferred_event do
    quota_definition_sid { Forgery(:basic).number }
    target_quota_definition_sid { Forgery(:basic).number }
    occurrence_timestamp { 24.hours.ago }
    transferred_amount { '86055072.137' }
    closing_date { '2022-10-28' }

    trait :with_quota_definition do
      after(:create) do |event, _evaluator|
        quota_definition = create(:quota_definition, validity_end_date: Date.tomorrow)
        event.quota_definition_sid = quota_definition.quota_definition_sid
        event.save
        event.reload
      end
    end

    trait :with_target_quota_definition do
      after(:create) do |event, _evaluator|
        quota_definition = create(:quota_definition, validity_end_date: Date.tomorrow)
        event.target_quota_definition_sid = quota_definition.quota_definition_sid
        event.save
        event.reload
      end
    end
  end

  factory :quota_exhaustion_event do
    quota_definition
    exhaustion_date { Time.zone.today }
    occurrence_timestamp { 24.hours.ago }
  end

  factory :quota_critical_event do
    quota_definition
    critical_state_change_date { Time.zone.today }
    occurrence_timestamp       { 24.hours.ago }

    trait :xml do
      critical_state { Forgery(:basic).text(exactly: 2) }
    end

    trait :active do
      critical_state { 'Y' }
    end

    trait :inactive do
      critical_state { 'N' }
    end
  end

  factory :quota_suspension_period do
    quota_suspension_period_sid  { generate(:sid) }
    quota_definition_sid         { generate(:sid) }
    suspension_start_date        { 1.year.ago.beginning_of_day }
    suspension_end_date          { 1.year.ago.beginning_of_day }
    description                  { Forgery(:lorem_ipsum).sentence }
  end

  factory :quota_unblocking_event do
    quota_definition
    occurrence_timestamp  { 24.hours.ago }
    unblocking_date       { 1.year.ago.beginning_of_day }
  end

  factory :quota_unsuspension_event do
    quota_definition_sid  { generate(:sid) }
    occurrence_timestamp  { 24.hours.ago }
    unsuspension_date     { 1.year.ago.beginning_of_day }
  end
end
