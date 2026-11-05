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

    expect(entry).to include({ name: 'candidate_limit', config_type: 'integer', min: 1, max: 250 })
  end

  it 'describes max_rounds with its own range' do
    entry = schema.find { |e| e[:name] == 'max_rounds' }

    expect(entry).to include({ name: 'max_rounds', config_type: 'integer', min: 1, max: 20 })
  end

  it 'describes the boolean keys with no extra metadata beyond a description' do
    entry = schema.find { |e| e[:name] == 'search_non_declarables' }

    expect(entry.keys).to match_array(%i[name config_type description])
    expect(entry[:description]).to be_present
  end

  it 'describes search_atars_enabled as a boolean, like the other search switches' do
    entry = schema.find { |e| e[:name] == 'search_atars_enabled' }

    expect(entry.keys).to match_array(%i[name config_type description])
    expect(entry[:config_type]).to eq('boolean')
  end

  # The operator reads this on the launch form. Without it they would assume the override also
  # changes the vector search, or that it can put ATaR keywords into an index built without them.
  it 'says search_atars_enabled changes the keyword search only, and needs an index built with ATaR keywords' do
    description = schema.find { |e| e[:name] == 'search_atars_enabled' }[:description]

    expect(description).to include('keyword search').and include('not the vector search').and include('built with ATaR keywords')
  end

  it 'lists search_atars_enabled straight after search_non_declarables, so the two search switches sit together on the launch form' do
    names = schema.map { |entry| entry[:name] }

    expect(names.index('search_atars_enabled')).to eq(names.index('search_non_declarables') + 1)
  end

  it 'gives every allowed override a plain-language description, not just type and range' do
    schema.each do |entry|
      expect(entry[:description]).to be_present, "#{entry[:name]} has no description"
    end
  end

  it 'describes reasoning_effort as options, listing every level any model supports from least to most' do
    entry = schema.find { |e| e[:name] == 'reasoning_effort' }

    expect(entry[:config_type]).to eq('options')
    expect(entry[:options]).to eq(%w[none minimal low medium high xhigh max].map { |level| { key: level, label: level } })
  end

  it 'lists every reasoning level any configured model supports as a reasoning_effort choice' do
    entry = schema.find { |e| e[:name] == 'reasoning_effort' }
    every_level = OpenaiClient::MODEL_CONFIGS.values.flat_map { |config| config[:reasoning_levels] }.uniq

    expect(entry[:options].map { |option| option[:key] }).to match_array(every_level)
  end

  it 'lists reasoning_effort straight after question_model, because the launch form shows fields in this order' do
    names = schema.map { |entry| entry[:name] }

    expect(names.index('reasoning_effort')).to eq(names.index('question_model') + 1)
  end
end
