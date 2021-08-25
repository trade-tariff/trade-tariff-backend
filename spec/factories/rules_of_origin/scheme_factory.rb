FactoryBot.define do
  factory :rules_of_origin_scheme, class: 'RulesOfOrigin::Scheme' do
    sequence(:scheme_code)  { |n| "SC#{n}" }
    sequence(:title)        { |n| "Scheme #{n}" }
    introductory_notes_file { 'intro_notes.md' }
    fta_intro_file          { 'fta_intro.md' }
    countries               { %w[FR ES IT DE] }
    footnote                { 'This scheme may be expanded in the future' }

    trait :with_links do
      links do
        [
          attributes_for(:rules_of_origin_link),
          attributes_for(:rules_of_origin_link),
        ]
      end
    end

    trait :with_explainers do
      explainers do
        [
          attributes_for(:rules_of_origin_explainer),
          attributes_for(:rules_of_origin_explainer),
        ]
      end
    end
  end
end
