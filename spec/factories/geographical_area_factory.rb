FactoryBot.define do
  sequence(:geographical_area_sid) { |n| n }
  sequence(:geographical_area_id)  { |n| n }

  factory :geographical_area do
    geographical_area_sid { generate(:geographical_area_sid) }
    geographical_area_id  { Forgery(:basic).text(exactly: 2) }
    validity_start_date   { Date.current.ago(3.years) }
    validity_end_date     { nil }

    trait :fifteen_years do
      validity_start_date { Date.current.ago(15.years) }
    end

    trait :twenty_years do
      validity_start_date { Date.current.ago(20.years) }
    end

    trait :erga_omnes do
      geographical_area_id { '1011' }
    end

    trait :country do
      geographical_code { '0' }
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
    validity_start_date                      { Date.current.ago(2.years) }
    validity_end_date                        { nil }
  end

  factory :geographical_area_description do
    transient do
      valid_at { Time.now.ago(2.years) }
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
    validity_start_date                      { Date.current.ago(2.years) }
    validity_end_date                        { nil }
  end
end
