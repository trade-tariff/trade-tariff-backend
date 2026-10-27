require 'rails_helper'

RSpec.describe EvaluationConfiguration::ReasoningEffort do
  describe '.resolve' do
    it 'keeps the configured effort when the model supports it' do
      expect(described_class.resolve(model: 'gpt-5.2', configured: 'high')).to eq('high')
    end

    it 'falls back to the most conservative level the model supports when it does not support the configured one' do
      expect(described_class.resolve(model: 'gpt-5.2', configured: 'xhigh')).to eq('none')
    end

    it 'falls back the same way when no effort is configured' do
      expect(described_class.resolve(model: 'gpt-5.2', configured: nil)).to eq('none')
    end

    it 'is nil for a model that does not reason' do
      expect(described_class.resolve(model: 'gpt-4o-mini', configured: 'medium')).to be_nil
    end

    it 'is nil for a model it does not know' do
      expect(described_class.resolve(model: 'not-a-model', configured: 'medium')).to be_nil
    end
  end

  describe '.apply' do
    it 'resolves the effort for the configuration\'s question model' do
      configuration = { 'question_model' => 'gpt-5.2', 'reasoning_effort' => 'xhigh', 'max_rounds' => 3 }

      expect(described_class.apply(configuration)).to eq('question_model' => 'gpt-5.2', 'reasoning_effort' => 'none', 'max_rounds' => 3)
    end

    it 'leaves out the effort for a model that does not reason' do
      configuration = { 'question_model' => 'gpt-4o-mini', 'reasoning_effort' => 'medium' }

      expect(described_class.apply(configuration)).to eq('question_model' => 'gpt-4o-mini')
    end

    it 'does not change the configuration it is given' do
      configuration = { 'question_model' => 'gpt-4o-mini', 'reasoning_effort' => 'medium' }

      described_class.apply(configuration)

      expect(configuration).to eq('question_model' => 'gpt-4o-mini', 'reasoning_effort' => 'medium')
    end
  end
end
