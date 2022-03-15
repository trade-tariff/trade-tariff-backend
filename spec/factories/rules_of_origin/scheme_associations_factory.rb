FactoryBot.define do
  factory :rules_of_origin_scheme_associations, class: 'RulesOfOrigin::SchemeAssociations' do
    initialize_with do
      RulesOfOrigin::SchemeAssociations.from_default_file.scheme_associations
    end
  end
end
