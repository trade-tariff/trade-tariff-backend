FactoryBot.define do
  factory :rules_of_origin_v2_rule_set, class: 'RulesOfOrigin::V2::RuleSet' do
    initialize_with { new attributes }

    transient do
      sequence(:rule_set_range) { |n| n }
      rule_count { 2 }
    end

    heading { sprintf '%03d0-%03d9', rule_set_range, rule_set_range }
    subdivision { '' }
    prefix { '' }
    min { sprintf '%09d0', rule_set_range }
    max { sprintf '%09d9', rule_set_range }
    valid { true }

    rules { attributes_for_list :rules_of_origin_v2_rule, rule_count }
  end
end
