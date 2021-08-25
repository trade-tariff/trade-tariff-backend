FactoryBot.define do
  factory :rules_of_origin_link, class: 'RulesOfOrigin::Link' do
    sequence(:text) { |n| "Explainer #{n}" }
    sequence(:url)  { |n| "explainer#{n}.md" }
  end
end
