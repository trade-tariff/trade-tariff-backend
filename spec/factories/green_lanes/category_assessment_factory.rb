FactoryBot.define do
  factory :category_assessment, class: 'GreenLanes::CategoryAssessment' do
    transient do
      measures_count { 1 }
    end

    regulation { create(:base_regulation) }
    measure_type { create(:measure_type) }
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

    trait :with_measures do
      before :create do |_, evaluator|
        create_list :measure, evaluator.measures_count,
                    measure_type_id: evaluator.measure_type.measure_type_id,
                    generating_regulation: evaluator.regulation
      end
    end

    trait :without_regulation do
      regulation { nil }
    end
  end
end
