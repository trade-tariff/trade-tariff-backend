FactoryBot.define do
  factory :rules_of_origin_data_set, class: 'RulesOfOrigin::DataSet' do
    initialize_with { new scheme_set, rule_set, heading_mappings }

    scheme_set { build :rules_of_origin_scheme_set }
    rule_set { build :rules_of_origin_rule_set, rules: rules }

    heading_mappings do
      build :rules_of_origin_heading_mappings,
            rule: rules.first,
            sub_heading: heading_code
    end

    transient do
      scheme_code { scheme_set.schemes.first }
      rules { build_list :rules_of_origin_rule, 2, scheme_code: scheme_code }
      sequence(:heading_code, 1000) { |n| sprintf '%6d', n }
    end
  end
end
