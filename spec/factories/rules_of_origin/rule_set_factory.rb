FactoryBot.define do
  factory :rules_of_origin_rule_set, class: 'RulesOfOrigin::RuleSet' do
    initialize_with do
      new(source_file).tap do |rule_set|
        rules.each do |rule|
          rule_set.add_rule rule.id_rule, rule.attributes.without(:id_rule)
        end
      end
    end

    transient do
      source_file { 'spec/fixtures/rules_of_origin/rules_of_origin_210728.csv' }
      rules { build_list(:rules_of_origin_rule, 2) }
    end
  end
end
