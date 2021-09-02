FactoryBot.define do
  factory :rules_of_origin_heading_mappings, class: 'RulesOfOrigin::HeadingMappings' do
    initialize_with do
      new(source_file).tap do |heading_mappings|
        mappings.each do |mapping|
          heading_mappings.add_mapping(*mapping)
        end
      end
    end

    transient do
      mappings do
        [
          [sub_heading, scheme_code, id_rule],
        ]
      end
      source_file { 'spec/fixtures/rules_of_origin/rules_to_commodities.csv' }
      sub_heading { '010101' }
      rule { build :rules_of_origin_rule }
      scheme_code { rule.scheme_code }
      id_rule { rule.id_rule }
    end
  end
end
