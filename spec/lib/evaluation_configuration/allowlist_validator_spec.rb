require 'rails_helper'

RSpec.describe EvaluationConfiguration::AllowlistValidator do
  it 'accepts an empty override set' do
    expect(described_class.call({})).to be true
  end

  it 'accepts every key on the MVP allowlist' do
    overrides = EvaluationConfiguration::ALLOWED_OVERRIDE_KEYS.index_with { |_key| 'value' }
    expect(described_class.call(overrides)).to be true
  end

  it 'accepts a subset of allowed keys' do
    expect(described_class.call({ 'simulator_model' => 'gpt-4o-mini' })).to be true
  end

  it 'rejects a key not on the allowlist' do
    expect {
      described_class.call({ 'use_kg_context' => true })
    }.to raise_error(EvaluationConfiguration::OverrideValidationError, /use_kg_context/)
  end

  it 'rejects a mix of allowed and disallowed keys, naming only the disallowed one' do
    error = nil
    begin
      described_class.call({ 'max_rounds' => 3, 'use_facts_vec' => true })
    rescue EvaluationConfiguration::OverrideValidationError => e
      error = e
    end
    expect(error.message).to include('use_facts_vec')
    expect(error.message).not_to include('max_rounds')
  end

  it 'accepts symbol keys as well as string keys' do
    expect(described_class.call({ max_rounds: 3 })).to be true
  end
end
