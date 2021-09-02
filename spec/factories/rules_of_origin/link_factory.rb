FactoryBot.define do
  factory :rules_of_origin_link, class: 'RulesOfOrigin::Link' do
    sequence(:text) { |n| "Link #{n}" }
    sequence(:url)  { |n| "https://gov.uk/some-external-link-#{n}" }
  end
end
