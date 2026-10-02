require 'rails_helper'

RSpec.describe EvaluationConfiguration::OverrideSchema do
  subject(:schema) { described_class.call }

  it 'lists every allowed override key' do
    expect(schema.map { |entry| entry[:name] }).to match_array(EvaluationConfiguration::ALLOWED_OVERRIDE_KEYS)
  end

  it 'describes the model keys as options, with every configured model as a choice' do
    entry = schema.find { |e| e[:name] == 'question_model' }

    expect(entry[:config_type]).to eq('options')
    expect(entry[:options]).to include({ key: 'gpt-5.4', label: 'gpt-5.4' })
    expect(entry[:options].map { |o| o[:key] }).to match_array(OpenaiClient::MODEL_CONFIGS.keys)
  end

  it 'describes simulator_model the same way as question_model' do
    entry = schema.find { |e| e[:name] == 'simulator_model' }

    expect(entry[:config_type]).to eq('options')
  end

  it 'describes the integer keys with their validator ranges' do
    entry = schema.find { |e| e[:name] == 'candidate_limit' }

    expect(entry).to eq({ name: 'candidate_limit', config_type: 'integer', min: 1, max: 250 })
  end

  it 'describes max_rounds with its own range' do
    entry = schema.find { |e| e[:name] == 'max_rounds' }

    expect(entry).to eq({ name: 'max_rounds', config_type: 'integer', min: 1, max: 20 })
  end

  it 'describes the boolean keys with no extra metadata' do
    entry = schema.find { |e| e[:name] == 'search_non_declarables' }

    expect(entry).to eq({ name: 'search_non_declarables', config_type: 'boolean' })
  end
end
