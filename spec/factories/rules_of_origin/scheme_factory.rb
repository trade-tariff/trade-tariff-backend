FactoryBot.define do
  factory :rules_of_origin_scheme, class: 'RulesOfOrigin::Scheme' do
    sequence(:scheme_code)  { |n| "SC#{n}" }
    sequence(:title)        { |n| "Scheme #{n}" }
    introductory_notes_file { 'intro_notes.md' }
    fta_intro_file          { 'fta_intro.md' }
    countries               { %w[FR ES IT DE] }
    footnote                { 'This scheme may be expanded in the future' }
    unilateral              { nil }

    trait :with_links do
      links { attributes_for_list :rules_of_origin_link, 2 }
    end

    trait :with_explainers do
      explainers { attributes_for_list :rules_of_origin_explainer, 2 }
    end

    trait :with_proofs do
      proofs { attributes_for_list :rules_of_origin_proof, 2 }
    end

    trait :with_origin_reference_document do
      ord { attributes_for :rules_of_origin_origin_reference_document }
    end

    trait :in_scheme_set do
      scheme_set { build :rules_of_origin_scheme_set, :without_data }
    end

    trait :with_articles do
      in_scheme_set
      scheme_code { 'test' }
    end
  end
end
