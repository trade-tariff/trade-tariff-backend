# rubocop:disable RSpec/DescribeClass
RSpec.describe 'admin_configurations:seed' do
  subject(:seed) do
    suppress_output { Rake::Task['admin_configurations:seed'].invoke }
  end

  after do
    Rake::Task['admin_configurations:seed'].reenable
  end

  it 'creates all 28 admin configurations', :aggregate_failures do
    expect { seed }.to change(AdminConfiguration, :count).by(28)

    names = AdminConfiguration.order(:name).select_map(:name)
    expect(names).to eq(%w[
      expand_model
      expand_query_context
      expand_search_enabled
      input_sanitiser_enabled
      input_sanitiser_max_length
      interactive_search_enabled
      interactive_search_max_questions
      label_context
      label_model
      label_page_size
      opensearch_result_limit
      pos_noun_boost
      pos_qualifier_boost
      pos_search_enabled
      search_context
      search_labels_enabled
      search_model
      search_result_limit
      self_text_batch_size
      self_text_context
      self_text_model
      suggest_chemical_cas
      suggest_chemical_cus
      suggest_chemical_names
      suggest_colloquial_terms
      suggest_known_brands
      suggest_results_limit
      suggest_synonyms
    ])
  end

  it 'seeds options configs with sorted model options', :aggregate_failures do
    seed

    %w[label_model search_model expand_model self_text_model].each do |name|
      config = AdminConfiguration.where(name:).first
      expect(config.config_type).to eq('options')
      expect(config.area).to eq('classification')
      expect(config.value['selected']).to eq(TradeTariffBackend.ai_model)

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

    expand_query = AdminConfiguration.where(name: 'expand_query_context').first
    expect(expand_query.config_type).to eq('markdown')
    expect(expand_query.value).to include('## Output format')
    expect(expand_query.value).to include('## Example')

    self_text_context = AdminConfiguration.where(name: 'self_text_context').first
    expect(self_text_context.config_type).to eq('markdown')
    expect(self_text_context.value).to include('## Output format')
    expect(self_text_context.value).to include('excluded_siblings')
  end

  it 'seeds self_text_batch_size as an integer config defaulting to 5', :aggregate_failures do
    seed

    config = AdminConfiguration.where(name: 'self_text_batch_size').first
    expect(config.config_type).to eq('integer')
    expect(config.area).to eq('classification')
    expect(config.value).to eq(5)
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
    expect(config.value).to be true
  end

  it 'seeds expand_search_enabled as a boolean config', :aggregate_failures do
    seed

    config = AdminConfiguration.where(name: 'expand_search_enabled').first
    expect(config.config_type).to eq('boolean')
    expect(config.area).to eq('classification')
    expect(config.value).to be true
  end

  it 'seeds interactive_search_enabled as a boolean config defaulting to true', :aggregate_failures do
    seed

    config = AdminConfiguration.where(name: 'interactive_search_enabled').first
    expect(config.config_type).to eq('boolean')
    expect(config.area).to eq('classification')
    expect(config.value).to be true
  end

  it 'seeds search_result_limit as an integer config defaulting to 0', :aggregate_failures do
    seed

    config = AdminConfiguration.where(name: 'search_result_limit').first
    expect(config.config_type).to eq('integer')
    expect(config.area).to eq('classification')
    expect(config.value).to eq(0)
  end

  it 'seeds opensearch_result_limit as an integer config defaulting to 80', :aggregate_failures do
    seed

    config = AdminConfiguration.where(name: 'opensearch_result_limit').first
    expect(config.config_type).to eq('integer')
    expect(config.area).to eq('classification')
    expect(config.value).to eq(80)
  end

  it 'seeds pos_noun_boost as an integer config defaulting to 10', :aggregate_failures do
    seed

    config = AdminConfiguration.where(name: 'pos_noun_boost').first
    expect(config.config_type).to eq('integer')
    expect(config.area).to eq('classification')
    expect(config.value).to eq(10)
  end

  it 'seeds pos_qualifier_boost as an integer config defaulting to 3', :aggregate_failures do
    seed

    config = AdminConfiguration.where(name: 'pos_qualifier_boost').first
    expect(config.config_type).to eq('integer')
    expect(config.area).to eq('classification')
    expect(config.value).to eq(3)
  end

  it 'seeds pos_search_enabled as a boolean config defaulting to true', :aggregate_failures do
    seed

    config = AdminConfiguration.where(name: 'pos_search_enabled').first
    expect(config.config_type).to eq('boolean')
    expect(config.area).to eq('classification')
    expect(config.value).to be true
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

    %w[label_context search_context expand_query_context self_text_context].each do |name|
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

  it 'refreshes the materialized view after creating records' do
    allow(AdminConfiguration).to receive(:refresh!).and_call_original

    seed

    # The oplog plugin also calls refresh! in test mode after each create,
    # so total calls = 28 (oplog) + 1 (rake task) = 29
    expect(AdminConfiguration).to have_received(:refresh!).with(concurrently: false).exactly(29).times
  end

  it 'does not refresh when nothing is created' do
    seed
    Rake::Task['admin_configurations:seed'].reenable
    allow(AdminConfiguration).to receive(:refresh!)

    suppress_output { Rake::Task['admin_configurations:seed'].invoke }

    expect(AdminConfiguration).not_to have_received(:refresh!)
  end
end
# rubocop:enable RSpec/DescribeClass
