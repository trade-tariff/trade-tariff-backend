FactoryBot.define do
  factory :green_lanes_theme, class: 'GreenLanes::Theme' do
    section               { 1 }
    sequence(:subsection) { |n| n }
    sequence(:theme)      { |n| "Theme #{n}" }
    description           { 'Some description' }
    category              { 2 }
  end
end
