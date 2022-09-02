FactoryBot.define do
  factory :measure_excluded_geographical_area do
    measure_sid { generate(:measure_sid) }
    geographical_area_sid { generate(:geographical_area_sid) }
    excluded_geographical_area { Forgery(:basic).text(exactly: 2).upcase }

    trait :with_geographical_area do
      with_geographical_area_country
    end

    trait :with_referenced_geographical_area_group_and_members do
      excluded_geographical_area { 'EU' }

      after(:create) do |measure_excluded_geographical_area, _evaluator|
        # referencing area
        create(
          :geographical_area,
          :country,
          geographical_area_id: measure_excluded_geographical_area.excluded_geographical_area,
          geographical_area_sid: measure_excluded_geographical_area.geographical_area_sid,
        )
        # referenced area
        group = create(
          :geographical_area,
          :group,
          geographical_area_id: '1013',
        )

        country = create(
          :geographical_area,
          :country,
        )

        create(
          :geographical_area_membership,
          geographical_area_sid: country.geographical_area_sid,
          geographical_area_group_sid: group.geographical_area_sid,
        )
      end
    end

    trait :with_geographical_area_group_and_members do
      after(:create) do |measure_excluded_geographical_area, _evaluator|
        group = create(
          :geographical_area,
          :group,
          geographical_area_id: measure_excluded_geographical_area.excluded_geographical_area,
          geographical_area_sid: measure_excluded_geographical_area.geographical_area_sid,
        )

        country = create(
          :geographical_area,
          :country,
        )

        create(
          :geographical_area_membership,
          geographical_area_sid: country.geographical_area_sid,
          geographical_area_group_sid: group.geographical_area_sid,
        )
      end
    end

    trait :with_geographical_area_country do
      after(:create) do |measure_excluded_geographical_area, _evaluator|
        create(
          :geographical_area,
          :country,
          geographical_area_id: measure_excluded_geographical_area.excluded_geographical_area,
          geographical_area_sid: measure_excluded_geographical_area.geographical_area_sid,
        )
      end
    end
  end
end
