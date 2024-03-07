FactoryBot.define do
  factory :green_lanes_theme, class: 'GreenLanes::Theme' do
    section               { 1 }
    sequence(:subsection) { |n| n }
    sequence(:theme)      { |n| "Theme #{n}" }
    description           { 'Some description' }
    category              { 2 }

    trait :category1 do
      category { 1 }
    end

    trait :category2 do
      category { 2 }
    end

    trait :category3 do
      category { 3 }
    end
  end
end
