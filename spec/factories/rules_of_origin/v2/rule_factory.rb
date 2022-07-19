FactoryBot.define do
  factory :rules_of_origin_v2_rule, class: 'RulesOfOrigin::V2::Rule' do
    sequence(:rule) { |n| "Rule #{n}" }
    original        { rule }
    rule_class      { [] }
    operator        { '' }
  end
end
