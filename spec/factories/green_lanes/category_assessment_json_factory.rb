FactoryBot.define do
  factory :category_assessment_json, class: 'GreenLanes::CategoryAssessmentJson' do
    transient do
      regulation { nil }
      measure_type { nil }
      measure { nil }
      geographical_area { nil }
    end

    sequence(:regulation_id) do |index|
      regulation&.regulation_id ||
        measure&.measure_generating_regulation_id ||
        sprintf('D%07d', index + 1)
    end

    sequence(:measure_type_id) do |index|
      measure_type&.measure_type_id ||
        measure&.measure_type_id ||
        (400 + index + 1).to_s
    end

    geographical_area_id do
      geographical_area&.geographical_area_id ||
        measure&.geographical_area_id ||
        GeographicalArea::ERGA_OMNES_ID
    end

    category { 1 }
    document_codes { [] }
    additional_codes { [] }
    theme { 'test theme' }

    trait :category2 do
      category { 2 }
    end

    trait :category3 do
      category { 3 }
    end
  end
end
