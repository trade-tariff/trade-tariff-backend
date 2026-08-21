# spec/lib/evaluation_configuration/merger_spec.rb
require 'rails_helper'

RSpec.describe EvaluationConfiguration::Merger do
  it 'overrides a top-level scalar value' do
    result = described_class.call({ 'max_rounds' => 5 }, { 'max_rounds' => 3 })
    expect(result).to eq({ 'max_rounds' => 3 })
  end

  it 'merges nested objects recursively rather than replacing the whole object' do
    baseline = { 'retrieval' => { 'rrf_k' => 60, 'vector_score_threshold' => 0.2 } }
    overrides = { 'retrieval' => { 'rrf_k' => 30 } }
    result = described_class.call(baseline, overrides)
    expect(result).to eq({ 'retrieval' => { 'rrf_k' => 30, 'vector_score_threshold' => 0.2 } })
  end

  it 'replaces arrays completely rather than concatenating or merging them' do
    baseline = { 'filter_prefixes' => %w[84 85] }
    overrides = { 'filter_prefixes' => %w[90] }
    result = described_class.call(baseline, overrides)
    expect(result).to eq({ 'filter_prefixes' => %w[90] })
  end

  it 'treats an explicit nil override as explicitly null, not as unset' do
    baseline = { 'search_non_declarables' => true }
    overrides = { 'search_non_declarables' => nil }
    result = described_class.call(baseline, overrides)
    expect(result).to eq({ 'search_non_declarables' => nil })
    expect(result.key?('search_non_declarables')).to be true
  end

  it 'applies multiple override layers left to right, later layers winning' do
    baseline = { 'max_rounds' => 5 }
    experiment_overrides = { 'max_rounds' => 3 }
    run_time_overrides = { 'max_rounds' => 1 }
    result = described_class.call(baseline, experiment_overrides, run_time_overrides)
    expect(result).to eq({ 'max_rounds' => 1 })
  end

  it 'leaves keys not mentioned in any override layer untouched' do
    baseline = { 'max_rounds' => 5, 'candidate_limit' => 20 }
    result = described_class.call(baseline, { 'max_rounds' => 3 })
    expect(result).to eq({ 'max_rounds' => 3, 'candidate_limit' => 20 })
  end
end
