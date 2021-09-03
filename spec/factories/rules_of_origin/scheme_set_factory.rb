FactoryBot.define do
  factory :rules_of_origin_scheme_set, class: 'RulesOfOrigin::SchemeSet' do
    initialize_with { new base_path, scheme_data.to_json }

    transient do
      base_path { Rails.root.join('spec/fixtures/rules_of_origin') }
      scope { 'uk' }
      links { [attributes_for(:rules_of_origin_link)] }
      schemes { [attributes_for(:rules_of_origin_scheme, :with_links)] }

      scheme_data do
        {
          'scope' => scope,
          'links' => links,
          'schemes' => schemes,
        }
      end
    end
  end
end
