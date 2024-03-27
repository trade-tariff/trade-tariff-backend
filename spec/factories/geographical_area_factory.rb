FactoryBot.define do
  sequence(:geographical_area_sid) { |n| n }
  sequence(:geographical_area_id)  { |n| n }

  factory :geographical_area do
    transient do
      members { [] }
    end

    geographical_area_sid { generate(:geographical_area_sid) }
    geographical_area_id  { Forgery(:basic).text(exactly: 2) }
    validity_start_date   { 3.years.ago.beginning_of_day }
    validity_end_date     { nil }

    after(:create) do |geographical_area, evaluator|
      Array.wrap(evaluator.members).each do |member|
        create(
          :geographical_area_membership,
          geographical_area_group_sid: geographical_area.geographical_area_sid,
          geographical_area_sid: member.geographical_area_sid,
        )
      end
    end

    trait :erga_omnes do
      geographical_area_id { '1011' }
    end

    trait :country do
      geographical_code { '0' }
    end

    trait :group do
      geographical_code { '1' }
      geographical_area_id { '1011' }
    end

    trait :globally_excluded do
      country
      geographical_area_id { 'EU' }
    end

    trait :with_gsp_least_developed_countries do
      geographical_area_id { '2005' }
    end

    trait :with_gsp_general_framework do
      geographical_area_id { '2020' }
    end

    trait :with_gsp_enhanced_framework do
      geographical_area_id { '2027' }
    end

    trait :with_dcts_standard_preferences do
      geographical_area_id { '1060' }
    end

    trait :with_dcts_enhanced_preferences do
      geographical_area_id { '1061' }
    end

    trait :with_dcts_comprehensive_preferences do
      geographical_area_id { '1062' }
    end

    trait :with_members do
      members do
        create_list(:geographical_area, 1,
                    :with_description,
                    :country,
                    geographical_area_id: 'RO')
      end
    end

    trait :with_reference_group_and_members do
      country

      geographical_area_id { 'EU' }

      after(:create) do |_geographical_area, _evaluator|
        group = create(
          :geographical_area,
          :group,
          geographical_area_id: '1013',
        )

        country = create(
          :geographical_area,
          :country,
          geographical_area_id: 'FR',
        )

        create(
          :geographical_area_membership,
          geographical_area_sid: country.geographical_area_sid,
          geographical_area_group_sid: group.geographical_area_sid,
        )
      end
    end

    trait :region do
      geographical_code { '2' }
    end

    trait :with_description do
      transient do
        geographical_area_description_period_sid { generate(:geographical_area_sid) }
      end

      after(:create) do |geographical_area, evaluator|
        geographical_area_description_period = create(
          :geographical_area_description_period,
          geographical_area_id: geographical_area.geographical_area_id,
          geographical_area_sid: geographical_area.geographical_area_sid,
          geographical_area_description_period_sid: evaluator.geographical_area_description_period_sid,
          validity_start_date: geographical_area.validity_start_date,
          validity_end_date: geographical_area.validity_end_date,
        )

        create(
          :geographical_area_description,
          geographical_area_id: geographical_area.geographical_area_id,
          geographical_area_sid: geographical_area.geographical_area_sid,
          geographical_area_description_period_sid: geographical_area_description_period.geographical_area_description_period_sid,
        )
      end
    end
  end

  factory :geographical_area_description_period do
    geographical_area_description_period_sid { generate(:geographical_area_sid) }
    geographical_area_sid                    { generate(:geographical_area_sid) }
    geographical_area_id                     { Forgery(:basic).text(exactly: 3) }
    validity_start_date                      { 2.years.ago.beginning_of_day }
    validity_end_date                        { nil }

    trait :with_description do
      after(:create) do |geographical_area_description_period, _evaluator|
        create(
          :geographical_area_description,
          geographical_area_id: geographical_area_description_period.geographical_area_id,
          geographical_area_sid: geographical_area_description_period.geographical_area_sid,
          geographical_area_description_period_sid: geographical_area_description_period.geographical_area_description_period_sid,
        )
      end
    end
  end

  factory :geographical_area_description do
    geographical_area_description_period_sid { generate(:geographical_area_sid) }
    geographical_area_sid                    { generate(:geographical_area_sid) }
    geographical_area_id                     { Forgery(:basic).text(exactly: 3) }
    description { Forgery(:lorem_ipsum).sentence }
  end

  factory :geographical_area_membership do
    geographical_area_sid                    { generate(:geographical_area_sid) }
    geographical_area_group_sid              { generate(:geographical_area_sid) }
    validity_start_date                      { 2.years.ago.beginning_of_day }
    validity_end_date                        { nil }
  end
end
