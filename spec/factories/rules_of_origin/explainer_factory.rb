FactoryBot.define do
  factory :rules_of_origin_explainer, class: 'RulesOfOrigin::Explainer' do
    sequence(:text) { |n| "Explainer #{n}" }
    sequence(:url)  { |n| "explainer#{n}.md" }
  end
end
