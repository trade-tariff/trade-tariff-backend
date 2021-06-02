FactoryBot.define do
  sequence(:quota_order_number_sid) { |n| n }
  sequence(:quota_order_number_id) do
    '09' + Forgery(:basic).number(at_least: 5000, at_most: 9999).to_s
  end

  factory :quota_association do
    main_quota_definition_sid  { Forgery(:basic).number }
    sub_quota_definition_sid   { Forgery(:basic).number }
    relation_type              { Forgery(:basic).text(exactly: 2) }
    coefficient                { Forgery(:basic).number }
  end

  factory :quota_order_number do
    quota_order_number_sid { generate(:quota_order_number_sid) }
    quota_order_number_id  { generate(:quota_order_number_id) }
    validity_start_date { Date.current.ago(4.years) }
    validity_end_date   { nil }

    trait :xml do
      validity_end_date { Date.current.ago(1.year) }
    end
  end

  factory :quota_order_number_origin do
    quota_order_number_origin_sid  { generate(:sid) }
    quota_order_number_sid         { generate(:sid) }
    geographical_area_id           { Forgery(:basic).text(exactly: 2) }
    geographical_area_sid          { generate(:sid) }
    validity_start_date            { Date.current.ago(4.years) }
    validity_end_date              { nil }

    trait :xml do
      validity_end_date { Date.current.ago(1.year) }
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
    reopening_date        { Date.current.ago(1.year) }
  end

  factory :quota_definition do
    quota_definition_sid            { generate(:quota_order_number_sid) }
    quota_order_number_sid          { generate(:quota_order_number_sid) }
    quota_order_number_id           { generate(:quota_order_number_id) }
    monetary_unit_code              { Forgery(:basic).text(exactly: 3) }
    measurement_unit_code           { Forgery(:basic).text(exactly: 3) }
    measurement_unit_qualifier_code { generate(:measurement_unit_qualifier_code) }

    trait :actual do
      validity_start_date { Date.current.ago(3.years) }
      validity_end_date   { nil }
    end

    trait :with_quota_balance_events do
      after(:create) do |quota_definition, _evaluator|
        create(:quota_balance_event, quota_definition: quota_definition)
      end
    end

    trait :xml do
      validity_start_date             { Date.current.ago(3.years) }
      validity_end_date               { Date.current.ago(1.year) }
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
    blocking_start_date        { Date.current.ago(1.year) }
    blocking_end_date          { Date.current.ago(1.year) }
    blocking_period_type       { Forgery(:basic).number }
    description                { Forgery(:lorem_ipsum).sentence }
  end

  factory :quota_exhaustion_event do
    quota_definition
    exhaustion_date { Date.current }
    occurrence_timestamp { 24.hours.ago }
  end

  factory :quota_critical_event do
    quota_definition
    critical_state_change_date { Date.current }
    occurrence_timestamp       { 24.hours.ago }

    trait :xml do
      critical_state { Forgery(:basic).text(exactly: 2) }
    end
  end

  factory :quota_suspension_period do
    quota_suspension_period_sid  { generate(:sid) }
    quota_definition_sid         { generate(:sid) }
    suspension_start_date        { Date.current.ago(1.year) }
    suspension_end_date          { Date.current.ago(1.year) }
    description                  { Forgery(:lorem_ipsum).sentence }
  end

  factory :quota_unblocking_event do
    quota_definition_sid  { generate(:sid) }
    occurrence_timestamp  { 24.hours.ago }
    unblocking_date       { Date.current.ago(1.year) }
  end

  factory :quota_unsuspension_event do
    quota_definition_sid  { generate(:sid) }
    occurrence_timestamp  { 24.hours.ago }
    unsuspension_date     { Date.current.ago(1.year) }
  end
end
