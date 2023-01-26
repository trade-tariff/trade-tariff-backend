FactoryBot.define do
  factory :measurement_unit_abbreviation do
    abbreviation { Forgery(:basic).text }
    measurement_unit_code { Forgery(:basic).text(exactly: 3) }

    trait :with_measurement_unit do
      after(:create) do |measurement_unit_abbreviation|
        create(:measurement_unit, :with_description, measurement_unit_code: measurement_unit_abbreviation.measurement_unit_code)
      end
    end

    trait :include_qualifier do
      sequence(:measurement_unit_qualifier, LoopingSequence.lower_a_to_upper_z, &:value)
    end
  end
end
