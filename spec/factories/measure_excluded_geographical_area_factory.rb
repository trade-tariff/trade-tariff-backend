FactoryBot.define do
  factory :measure_excluded_geographical_area do
    country

    measure_sid { generate(:measure_sid) }
    geographical_area_sid { generate(:geographical_area_sid) }
    excluded_geographical_area { Forgery(:basic).text(exactly: 2).upcase }

    trait :with_geographical_area do
      after(:create) do |measure_excluded_geographical_area, evaluator|
        geographical_area_id = measure_excluded_geographical_area.excluded_geographical_area
        geographical_area_sid = measure_excluded_geographical_area.geographical_area_sid

        if evaluator.group
          group = create(
            :geographical_area,
            :group,
            geographical_area_id:,
            geographical_area_sid:,
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
        else
          create(
            :geographical_area,
            :country,
            geographical_area_id:,
            geographical_area_sid:,
          )
        end
      end
    end

    trait :group do
      transient do
        group { true }
      end
    end

    trait :country do
      transient do
        group { false }
      end
    end
  end
end
