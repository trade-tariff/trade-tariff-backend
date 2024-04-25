FactoryBot.define do
  factory :green_lanes_exemption, class: 'GreenLanes::Exemption' do
    transient do
      category_assessments { [] }
    end

    sequence(:code) { |n| sprintf '%04d', n }
    description { Forgery(:basic).text }
    category_assessment_pks { category_assessments.map(&:pk) }
  end
end
