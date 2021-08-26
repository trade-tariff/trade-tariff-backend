FactoryBot.define do
  factory :rules_of_origin_rule, class: 'RulesOfOrigin::Rule' do
    sequence(:id_rule)     { |n| n }
    sequence(:scheme_code) { |n| "SCHEME#{n}" }
    sequence(:heading)     { |n| "#{n}.01" }
    description            { 'Fish and crustaceans' }
    rule                   { 'All animals are wholly obtained' }
  end
end
