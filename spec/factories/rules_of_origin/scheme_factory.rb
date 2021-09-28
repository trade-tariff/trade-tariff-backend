FactoryBot.define do
  factory :rules_of_origin_scheme, class: 'RulesOfOrigin::Scheme' do
    sequence(:scheme_code)  { |n| "SC#{n}" }
    sequence(:title)        { |n| "Scheme #{n}" }
    introductory_notes_file { 'intro_notes.md' }
    fta_intro_file          { 'fta_intro.md' }
    countries               { %w[FR ES IT DE] }
    footnote                { 'This scheme may be expanded in the future' }

    trait :with_links do
      links { attributes_for_list :rules_of_origin_link, 2 }
    end

    trait :with_explainers do
      explainers { attributes_for_list :rules_of_origin_explainer, 2 }
    end

    trait :with_proofs do
      proofs { attributes_for_list :rules_of_origin_proof, 2 }
    end
  end
end
