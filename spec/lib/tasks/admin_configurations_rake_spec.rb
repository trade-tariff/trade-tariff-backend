# rubocop:disable RSpec/DescribeClass
RSpec.describe 'admin_configurations:seed' do
  subject(:seed) do
    suppress_output { Rake::Task['admin_configurations:seed'].invoke }
  end

  after do
    Rake::Task['admin_configurations:seed'].reenable
  end

  it 'creates all 36 admin configurations', :aggregate_failures do
    expect { seed }.to change(AdminConfiguration, :count).by(36)

    names = AdminConfiguration.order(:name).select_map(:name)
    expect(names).to eq(%w[
      expand_model
      expand_query_context
      expand_search_enabled
      input_sanitiser_enabled
      input_sanitiser_max_length
      interactive_search_enabled
      interactive_search_excluded_chapters
      interactive_search_max_questions
      label_context
      label_model
      label_page_size
      non_other_self_text_batch_size
      non_other_self_text_context
      non_other_self_text_model
      opensearch_result_limit
      other_self_text_batch_size
      other_self_text_context
      other_self_text_model
      pos_noun_boost
      pos_qualifier_boost
      pos_search_enabled
      retrieval_method
      rrf_k
      search_context
      search_labels_enabled
      search_model
      search_result_limit
      suggest_chemical_cas
      suggest_chemical_cus
      suggest_chemical_names
      suggest_colloquial_terms
      suggest_known_brands
      suggest_results_limit
      suggest_synonyms
      vector_ef_search
      vector_score_threshold
    ])
  end

  it 'seeds nested_options configs with sorted model options', :aggregate_failures do
    seed

    expected_defaults = {
      'expand_model' => AdminConfiguration.nested_option_default_for('expand_model'),
      'label_model' => AdminConfiguration.nested_option_default_for('label_model'),
      'search_model' => AdminConfiguration.nested_option_default_for('search_model'),
      'other_self_text_model' => AdminConfiguration.nested_option_default_for('other_self_text_model'),
      'non_other_self_text_model' => AdminConfiguration.nested_option_default_for('non_other_self_text_model'),
    }

    expected_defaults.each do |name, expected|
      config = AdminConfiguration.where(name:).first
      expect(config.config_type).to eq('nested_options')
      expect(config.area).to eq('classification')
      expect(config.value['selected']).to eq(expected[:selected])
      expect(config.value['sub_values']).to eq(expected[:sub_values])

      option_keys = config.value['options'].map { |o| o['key'] }
      expect(option_keys).to eq(option_keys.sort)

      OpenaiClient::MODEL_CONFIGS.each_key do |model_key|
        expect(option_keys).to include(model_key)
      end
    end
  end

  it 'seeds markdown configs with legible markdown content', :aggregate_failures do
    seed

    label_context = AdminConfiguration.where(name: 'label_context').first
    expect(label_context.config_type).to eq('markdown')
    expect(label_context.value).to include('## Input fields')
    expect(label_context.value).to include('**commodity_code**')

    search_context = AdminConfiguration.where(name: 'search_context').first
    expect(search_context.config_type).to eq('markdown')
    expect(search_context.value).to include('## Response format')
    expect(search_context.value).to include('### Confident answer')
    expect(search_context.value).to include('Ask exactly one question per turn')
    expect(search_context.value).not_to include('Try and ask at least a few questions each time')

    expand_query = AdminConfiguration.where(name: 'expand_query_context').first
    expect(expand_query.config_type).to eq('markdown')
    expect(expand_query.value).to include('## Output format')
    expect(expand_query.value).to include('## Example')

    other_self_text_context = AdminConfiguration.where(name: 'other_self_text_context').first
    expect(other_self_text_context.config_type).to eq('markdown')
    expect(other_self_text_context.value).to include('## Output format')
    expect(other_self_text_context.value).to include('excluded_siblings')
    expect(other_self_text_context.value).to include('## Qualified Other patterns')

    non_other_self_text_context = AdminConfiguration.where(name: 'non_other_self_text_context').first
    expect(non_other_self_text_context.config_type).to eq('markdown')
    expect(non_other_self_text_context.value).to include('## Output format')
    expect(non_other_self_text_context.value).to include('## Style rules')
  end

  it 'seeds other_self_text_batch_size as an integer config defaulting to 5', :aggregate_failures do
    seed

    config = AdminConfiguration.where(name: 'other_self_text_batch_size').first
    expect(config.config_type).to eq('integer')
    expect(config.area).to eq('classification')
    expect(config.value).to eq(5)
  end

  it 'seeds non_other_self_text_batch_size as an integer config defaulting to 15', :aggregate_failures do
    seed

    config = AdminConfiguration.where(name: 'non_other_self_text_batch_size').first
    expect(config.config_type).to eq('integer')
    expect(config.area).to eq('classification')
    expect(config.value).to eq(15)
  end

  it 'seeds label_page_size as an integer config with the current page size', :aggregate_failures do
    seed

    config = AdminConfiguration.where(name: 'label_page_size').first
    expect(config.config_type).to eq('integer')
    expect(config.area).to eq('classification')
    expect(config.value).to eq(TradeTariffBackend.goods_nomenclature_label_page_size)
  end

  it 'seeds search_labels_enabled as a boolean config', :aggregate_failures do
    seed

    config = AdminConfiguration.where(name: 'search_labels_enabled').first
    expect(config.config_type).to eq('boolean')
    expect(config.area).to eq('classification')
    expect(config.value).to be(AdminConfiguration.default_for('search_labels_enabled'))
  end

  it 'seeds expand_search_enabled as a boolean config', :aggregate_failures do
    seed

    config = AdminConfiguration.where(name: 'expand_search_enabled').first
    expect(config.config_type).to eq('boolean')
    expect(config.area).to eq('classification')
    expect(config.value).to be(AdminConfiguration.default_for('expand_search_enabled'))
  end

  it 'seeds interactive_search_enabled as a boolean config defaulting to true', :aggregate_failures do
    seed

    config = AdminConfiguration.where(name: 'interactive_search_enabled').first
    expect(config.config_type).to eq('boolean')
    expect(config.area).to eq('classification')
    expect(config.value).to be(AdminConfiguration.default_for('interactive_search_enabled'))
  end

  it 'seeds interactive_search_excluded_chapters as a multi_options config defaulting to chapters 98 and 99', :aggregate_failures do
    seed

    config = AdminConfiguration.where(name: 'interactive_search_excluded_chapters').first
    expect(config.config_type).to eq('multi_options')
    expect(config.area).to eq('classification')
    expect(config.value['selected']).to eq(%w[98 99])
    expect(config.value['options']).to include(
      { 'key' => '98', 'label' => 'Chapter 98' },
      { 'key' => '99', 'label' => 'Chapter 99' },
    )
  end

  it 'seeds search_result_limit as an integer config defaulting to 0', :aggregate_failures do
    seed

    config = AdminConfiguration.where(name: 'search_result_limit').first
    expect(config.config_type).to eq('integer')
    expect(config.area).to eq('classification')
    expect(config.value).to eq(AdminConfiguration.default_for('search_result_limit'))
  end

  it 'seeds opensearch_result_limit from the AdminConfiguration default', :aggregate_failures do
    seed

    config = AdminConfiguration.where(name: 'opensearch_result_limit').first
    expect(config.config_type).to eq('integer')
    expect(config.area).to eq('classification')
    expect(config.value).to eq(AdminConfiguration.default_for('opensearch_result_limit'))
  end

  it 'seeds pos_noun_boost from the AdminConfiguration default', :aggregate_failures do
    seed

    config = AdminConfiguration.where(name: 'pos_noun_boost').first
    expect(config.config_type).to eq('integer')
    expect(config.area).to eq('classification')
    expect(config.value).to eq(AdminConfiguration.default_for('pos_noun_boost'))
  end

  it 'seeds pos_qualifier_boost from the AdminConfiguration default', :aggregate_failures do
    seed

    config = AdminConfiguration.where(name: 'pos_qualifier_boost').first
    expect(config.config_type).to eq('integer')
    expect(config.area).to eq('classification')
    expect(config.value).to eq(AdminConfiguration.default_for('pos_qualifier_boost'))
  end

  it 'seeds pos_search_enabled from the AdminConfiguration default', :aggregate_failures do
    seed

    config = AdminConfiguration.where(name: 'pos_search_enabled').first
    expect(config.config_type).to eq('boolean')
    expect(config.area).to eq('classification')
    expect(config.value).to be(AdminConfiguration.default_for('pos_search_enabled'))
  end

  it 'seeds retrieval_method from the AdminConfiguration default', :aggregate_failures do
    seed

    config = AdminConfiguration.where(name: 'retrieval_method').first
    expect(config.config_type).to eq('options')
    expect(config.area).to eq('classification')
    expect(config.value['selected']).to eq(AdminConfiguration.default_for('retrieval_method'))

    option_keys = config.value['options'].map { |o| o['key'] }
    expect(option_keys).to contain_exactly('opensearch', 'vector', 'hybrid')
  end

  it 'seeds vector_ef_search from the AdminConfiguration default', :aggregate_failures do
    seed

    config = AdminConfiguration.where(name: 'vector_ef_search').first
    expect(config.config_type).to eq('integer')
    expect(config.area).to eq('classification')
    expect(config.value).to eq(AdminConfiguration.default_for('vector_ef_search'))
  end

  it 'seeds rrf_k from the AdminConfiguration default', :aggregate_failures do
    seed

    config = AdminConfiguration.where(name: 'rrf_k').first
    expect(config.config_type).to eq('integer')
    expect(config.area).to eq('classification')
    expect(config.value).to eq(AdminConfiguration.default_for('rrf_k'))
  end

  it 'seeds suggestion toggle configs as booleans', :aggregate_failures do
    seed

    expected_defaults = {
      'suggest_chemical_cas' => false,
      'suggest_chemical_cus' => false,
      'suggest_chemical_names' => false,
      'suggest_colloquial_terms' => false,
      'suggest_known_brands' => false,
      'suggest_synonyms' => false,
    }

    expected_defaults.each do |name, expected_value|
      config = AdminConfiguration.where(name:).first
      expect(config.config_type).to eq('boolean'), "#{name} should be boolean"
      expect(config.area).to eq('classification'), "#{name} should be classification area"
      expect(config.value).to be(expected_value), "#{name} should default to #{expected_value}"
    end
  end

  it 'uses indented code blocks instead of fenced blocks for Govspeak compatibility', :aggregate_failures do
    seed

    %w[label_context search_context expand_query_context other_self_text_context non_other_self_text_context].each do |name|
      config = AdminConfiguration.where(name:).first
      expect(config.value).not_to include('```'), "#{name} should not contain fenced code blocks"
    end
  end

  it 'is idempotent — running twice does not duplicate records' do
    seed
    Rake::Task['admin_configurations:seed'].reenable

    expect { suppress_output { Rake::Task['admin_configurations:seed'].invoke } }
      .not_to change(AdminConfiguration, :count)
  end
end
# rubocop:enable RSpec/DescribeClass
