FactoryBot.define do
  sequence(:geographical_area_sid) { |n| n }
  sequence(:geographical_area_id)  { |n| n }

  factory :geographical_area do
    geographical_area_sid { generate(:geographical_area_sid) }
    geographical_area_id  { Forgery(:basic).text(exactly: 2) }
    validity_start_date   { 3.years.ago.beginning_of_day }
    validity_end_date     { nil }

    trait :fifteen_years do
      validity_start_date { 15.years.ago.beginning_of_day }
    end

    trait :twenty_years do
      validity_start_date { 20.years.ago.beginning_of_day }
    end

    trait :erga_omnes do
      geographical_area_id { '1011' }
    end

    trait :country do
      geographical_code { '0' }
    end

    trait :group do
      geographical_code { '1' }
    end

    trait :region do
      geographical_code { '2' }
    end

    after(:build) do |geographical_area, _evaluator|
      FactoryBot.create(:geographical_area_description, :with_period,
                        geographical_area_id: geographical_area.geographical_area_id,
                        geographical_area_sid: geographical_area.geographical_area_sid,
                        valid_at: geographical_area.validity_start_date,
                        valid_to: geographical_area.validity_end_date)
    end

    trait :with_description do
      # noop
    end
  end

  factory :geographical_area_description_period do
    geographical_area_description_period_sid { generate(:geographical_area_sid) }
    geographical_area_sid                    { generate(:geographical_area_sid) }
    geographical_area_id                     { Forgery(:basic).text(exactly: 3) }
    validity_start_date                      { 2.years.ago.beginning_of_day }
    validity_end_date                        { nil }
  end

  factory :geographical_area_description do
    transient do
      valid_at { Time.zone.now.ago(2.years) }
      valid_to { nil }
    end

    geographical_area_description_period_sid { generate(:geographical_area_sid) }
    geographical_area_sid                    { generate(:geographical_area_sid) }
    geographical_area_id                     { Forgery(:basic).text(exactly: 3) }
    description { Forgery(:lorem_ipsum).sentence }

    trait :with_period do
      after(:create) do |ga_description, evaluator|
        FactoryBot.create(:geographical_area_description_period, geographical_area_description_period_sid: ga_description.geographical_area_description_period_sid,
                                                                 geographical_area_sid: ga_description.geographical_area_sid,
                                                                 geographical_area_id: ga_description.geographical_area_id,
                                                                 validity_start_date: evaluator.valid_at,
                                                                 validity_end_date: evaluator.valid_to)
      end
    end
  end

  factory :geographical_area_membership do
    geographical_area_sid                    { generate(:geographical_area_sid) }
    geographical_area_group_sid              { generate(:geographical_area_sid) }
    validity_start_date                      { 2.years.ago.beginning_of_day }
    validity_end_date                        { nil }
  end
end
