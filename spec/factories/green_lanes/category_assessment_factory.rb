FactoryBot.define do
  factory :category_assessment, class: 'GreenLanes::CategoryAssessment' do
    transient do
      regulation { nil }
      measure_type { nil }
      measure { nil }
    end

    sequence(:regulation_id) do |index|
      regulation&.regulation_id ||
        measure&.measure_generating_regulation_id ||
        sprintf('D%07d', index + 1)
    end

    regulation_role do
      regulation&.regulation_role ||
        measure&.measure_generating_regulation_role ||
        1
    end

    sequence(:measure_type_id) do |index|
      measure_type&.measure_type_id ||
        measure&.measure_type_id ||
        (400 + index + 1).to_s
    end

    theme { create :green_lanes_theme }

    trait :category1 do
      theme { create :green_lanes_theme, :category1 }
    end

    trait :category2 do
      theme { create :green_lanes_theme, :category2 }
    end

    trait :category3 do
      theme { create :green_lanes_theme, :category3 }
    end
  end
end
