FactoryBot.define do
  factory :measure_excluded_geographical_area do
    country

    measure_sid { generate(:measure_sid) }
    geographical_area_sid { generate(:geographical_area_sid) }
    excluded_geographical_area do
      if referenced
        'EU'
      else
        Forgery(:basic).text(exactly: 2).upcase
      end
    end

    trait :with_geographical_area do
      after(:create) do |measure_excluded_geographical_area, evaluator|
        geographical_area_id = measure_excluded_geographical_area.excluded_geographical_area
        geographical_area_sid = measure_excluded_geographical_area.geographical_area_sid

        if evaluator.group
          group = if evaluator.referenced
                    # referencing area
                    create(
                      :geographical_area,
                      :country,
                      geographical_area_id:,
                      geographical_area_sid:,
                    )
                    # referenced area
                    create(
                      :geographical_area,
                      :group,
                      geographical_area_id: '1013',
                    )
                  else
                    create(
                      :geographical_area,
                      :group,
                      geographical_area_id:,
                      geographical_area_sid:,
                    )
                  end

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

    trait :referenced_group do
      transient do
        referenced { true }
        group { true }
      end
    end

    trait :group do
      transient do
        referenced { false }
        group { true }
      end
    end

    trait :country do
      transient do
        referenced { false }
        group { false }
      end
    end
  end
end
