FactoryBot.define do
  factory :rules_of_origin_proof, class: 'RulesOfOrigin::Proof' do
    sequence(:summary) { |n| "Proof #{n}" }
    sequence(:detail)  { |n| "proof-#{n}.md" }
  end
end
