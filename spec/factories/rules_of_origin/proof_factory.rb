FactoryBot.define do
  factory :rules_of_origin_proof, class: 'RulesOfOrigin::Proof' do
    sequence(:summary) { |n| "Proof #{n}" }
    sequence(:detail)  { |n| "proof-#{n}.md" }
    sequence(:proof_class) { |n| "origin-declaration-#{n}" }
    subtext { 'subtext' }
    content { "Opening paragraph\n\n* Some\n* Bullet\n* Points" }

    trait :with_scheme do
      scheme { build :rules_of_origin_scheme }
    end
  end
end
