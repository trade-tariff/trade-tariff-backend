require 'rails_helper'

RSpec.describe EvaluationConfiguration::AllowlistValidator do
  it 'accepts an empty override set' do
    expect(described_class.call({})).to be true
  end

  def valid_overrides
    {
      'question_model' => 'gpt-4o-mini',
      'simulator_model' => 'gpt-4.1-mini-2025-04-14',
      'candidate_limit' => 50,
      'max_rounds' => 7,
      'rrf_k' => 60,
      'vector_score_threshold' => 35,
      'vector_ef_search' => 100,
      'search_non_declarables' => false,
      'search_compressed_notes_enabled' => true,
      'search_general_rules_enabled' => false,
    }
  end

  it 'accepts every key on the allowlist with valid values' do
    expect(described_class.call(valid_overrides)).to be true
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

  describe 'question_model / simulator_model' do
    %w[question_model simulator_model].each do |key|
      it "accepts any model listed in OpenaiClient::MODEL_CONFIGS for #{key}" do
        OpenaiClient::MODEL_CONFIGS.each_key do |model|
          expect(described_class.call({ key => model })).to be true
        end
      end

      it "rejects a model not present in OpenaiClient::MODEL_CONFIGS for #{key}" do
        expect {
          described_class.call({ key => 'not-a-real-model' })
        }.to raise_error(EvaluationConfiguration::OverrideValidationError, /#{key}/)
      end

      it "rejects a non-String value for #{key}" do
        expect {
          described_class.call({ key => 42 })
        }.to raise_error(EvaluationConfiguration::OverrideValidationError, /#{key}/)
      end
    end
  end

  describe 'candidate_limit' do
    it 'accepts a positive Integer within range' do
      expect(described_class.call({ 'candidate_limit' => 100 })).to be true
    end

    it 'rejects a stringly-typed Integer' do
      expect {
        described_class.call({ 'candidate_limit' => '5' })
      }.to raise_error(EvaluationConfiguration::OverrideValidationError, /candidate_limit/)
    end

    it 'rejects zero' do
      expect {
        described_class.call({ 'candidate_limit' => 0 })
      }.to raise_error(EvaluationConfiguration::OverrideValidationError, /candidate_limit/)
    end

    it 'rejects a negative value' do
      expect {
        described_class.call({ 'candidate_limit' => -1 })
      }.to raise_error(EvaluationConfiguration::OverrideValidationError, /candidate_limit/)
    end

    it 'rejects an excessively large value' do
      expect {
        described_class.call({ 'candidate_limit' => 100_000 })
      }.to raise_error(EvaluationConfiguration::OverrideValidationError, /candidate_limit/)
    end
  end

  describe 'max_rounds' do
    it 'accepts a positive Integer within range' do
      expect(described_class.call({ 'max_rounds' => 5 })).to be true
    end

    it 'rejects a float' do
      expect {
        described_class.call({ 'max_rounds' => 5.5 })
      }.to raise_error(EvaluationConfiguration::OverrideValidationError, /max_rounds/)
    end

    it 'rejects zero' do
      expect {
        described_class.call({ 'max_rounds' => 0 })
      }.to raise_error(EvaluationConfiguration::OverrideValidationError, /max_rounds/)
    end

    it 'rejects an excessively large value' do
      expect {
        described_class.call({ 'max_rounds' => 1000 })
      }.to raise_error(EvaluationConfiguration::OverrideValidationError, /max_rounds/)
    end
  end

  describe 'rrf_k' do
    it 'accepts zero' do
      expect(described_class.call({ 'rrf_k' => 0 })).to be true
    end

    it 'accepts a typical positive value' do
      expect(described_class.call({ 'rrf_k' => 60 })).to be true
    end

    it 'rejects a negative value' do
      expect {
        described_class.call({ 'rrf_k' => -1 })
      }.to raise_error(EvaluationConfiguration::OverrideValidationError, /rrf_k/)
    end

    it 'rejects a non-Integer value' do
      expect {
        described_class.call({ 'rrf_k' => 'abc' })
      }.to raise_error(EvaluationConfiguration::OverrideValidationError, /rrf_k/)
    end

    it 'rejects an excessively large value' do
      expect {
        described_class.call({ 'rrf_k' => 1_000_000 })
      }.to raise_error(EvaluationConfiguration::OverrideValidationError, /rrf_k/)
    end
  end

  describe 'vector_score_threshold' do
    it 'accepts the boundaries of 0..100' do
      expect(described_class.call({ 'vector_score_threshold' => 0 })).to be true
      expect(described_class.call({ 'vector_score_threshold' => 100 })).to be true
    end

    it 'rejects a value above 100' do
      expect {
        described_class.call({ 'vector_score_threshold' => 101 })
      }.to raise_error(EvaluationConfiguration::OverrideValidationError, /vector_score_threshold/)
    end

    it 'rejects a negative value' do
      expect {
        described_class.call({ 'vector_score_threshold' => -1 })
      }.to raise_error(EvaluationConfiguration::OverrideValidationError, /vector_score_threshold/)
    end

    it 'rejects a non-Integer value' do
      expect {
        described_class.call({ 'vector_score_threshold' => '50' })
      }.to raise_error(EvaluationConfiguration::OverrideValidationError, /vector_score_threshold/)
    end
  end

  describe 'vector_ef_search' do
    it 'accepts a positive Integer within range' do
      expect(described_class.call({ 'vector_ef_search' => 100 })).to be true
    end

    it 'rejects zero' do
      expect {
        described_class.call({ 'vector_ef_search' => 0 })
      }.to raise_error(EvaluationConfiguration::OverrideValidationError, /vector_ef_search/)
    end

    it 'rejects a negative value' do
      expect {
        described_class.call({ 'vector_ef_search' => -5 })
      }.to raise_error(EvaluationConfiguration::OverrideValidationError, /vector_ef_search/)
    end

    it 'rejects an excessively large value' do
      expect {
        described_class.call({ 'vector_ef_search' => 100_000 })
      }.to raise_error(EvaluationConfiguration::OverrideValidationError, /vector_ef_search/)
    end
  end

  describe 'boolean keys' do
    %w[search_non_declarables search_compressed_notes_enabled search_general_rules_enabled].each do |key|
      it "accepts true and false for #{key}" do
        expect(described_class.call({ key => true })).to be true
        expect(described_class.call({ key => false })).to be true
      end

      it "rejects a String for #{key}" do
        expect {
          described_class.call({ key => 'true' })
        }.to raise_error(EvaluationConfiguration::OverrideValidationError, /#{key}/)
      end

      it "rejects a non-boolean, non-String value for #{key}" do
        expect {
          described_class.call({ key => 1 })
        }.to raise_error(EvaluationConfiguration::OverrideValidationError, /#{key}/)
      end
    end
  end
end
