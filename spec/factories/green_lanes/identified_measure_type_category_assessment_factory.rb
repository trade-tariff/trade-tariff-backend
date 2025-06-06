FactoryBot.define do
  factory :identified_measure_type_category_assessment,
          class: 'GreenLanes::IdentifiedMeasureTypeCategoryAssessment' do
    transient do
      measure { nil }
    end

    measure_type do
      measure&.measure_type || association(:measure_type)
    end

    after(:build) do |assessment, _evaluator|
      assessment.measure_type_id = assessment.measure_type.measure_type_id
    end

    theme do
      create :green_lanes_theme
    end
  end
end
