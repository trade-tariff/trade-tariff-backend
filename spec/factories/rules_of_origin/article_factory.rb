FactoryBot.define do
  factory :rules_of_origin_article, class: 'RulesOfOrigin::Article' do
    scheme { build :rules_of_origin_scheme, scheme_code: 'test' }
    article { 'test-article' }
  end
end
