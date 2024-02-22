FactoryBot.define do
  factory :category_assessment, class: 'GreenLanes::CategoryAssessment' do
    transient do
      measure { nil }
    end

    regulation { measure&.regulation || create(:base_regulation) }
    measure_type { measure&.measure_type || create(:measure_type) }
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
