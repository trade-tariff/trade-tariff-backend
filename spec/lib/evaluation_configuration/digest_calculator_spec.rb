require 'rails_helper'

RSpec.describe EvaluationConfiguration::DigestCalculator do
  it 'returns a 16-character lowercase hex string' do
    digest = described_class.call({ 'max_rounds' => 3 })
    expect(digest).to match(/\A[0-9a-f]{16}\z/)
  end

  it 'is deterministic for the same configuration' do
    config = { 'max_rounds' => 3, 'question_model' => 'gpt-4o' }
    first_digest = described_class.call(config)
    second_digest = described_class.call(config)
    expect(first_digest).to eq(second_digest)
  end

  it 'is independent of hash key order' do
    a = { 'max_rounds' => 3, 'question_model' => 'gpt-4o' }
    b = { 'question_model' => 'gpt-4o', 'max_rounds' => 3 }
    expect(described_class.call(a)).to eq(described_class.call(b))
  end

  it 'is independent of nested hash key order' do
    a = { 'retrieval' => { 'rrf_k' => 60, 'vector_score_threshold' => 0.2 } }
    b = { 'retrieval' => { 'vector_score_threshold' => 0.2, 'rrf_k' => 60 } }
    expect(described_class.call(a)).to eq(described_class.call(b))
  end

  it 'produces a different digest when a value actually differs' do
    a = { 'max_rounds' => 3 }
    b = { 'max_rounds' => 4 }
    expect(described_class.call(a)).not_to eq(described_class.call(b))
  end

  it 'produces a different digest when array order differs' do
    a = { 'filter_prefixes' => %w[84 85] }
    b = { 'filter_prefixes' => %w[85 84] }
    expect(described_class.call(a)).not_to eq(described_class.call(b))
  end
end
