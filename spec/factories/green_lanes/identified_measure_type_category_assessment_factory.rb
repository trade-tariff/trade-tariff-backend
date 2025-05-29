FactoryBot.define do
  factory :identified_measure_type_category_assessment, class: 'GreenLanes::IdentifiedMeasureTypeCategoryAssessment' do
    transient do
      measure { nil }
    end

    measure_type { measure&.measure_type || create(:measure_type) }
    measure_type_id { measure_type.measure_type_id }

    theme { create :green_lanes_theme }
  end
end
