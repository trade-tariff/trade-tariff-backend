require 'rails_helper'

RSpec.describe EvaluationRun do
  describe '.start!' do
    let(:experiment) do
      create(
        :evaluation_experiment,
        name: 'start-spec-experiment',
        configuration_overrides: { 'simulator_model' => 'gpt-4o-mini' },
      )
    end

    it 'creates a run with an effective_configuration merging baseline and experiment overrides' do
      run = described_class.start!(experiment:, triggered_by: 'operator')
      expect(run.effective_configuration['simulator_model']).to eq('gpt-4o-mini')
    end

    it 'applies run-time overrides on top of the experiment overrides' do
      run = described_class.start!(
        experiment:, triggered_by: 'operator',
        run_time_overrides: { 'simulator_model' => 'gpt-4o' }
      )
      expect(run.effective_configuration['simulator_model']).to eq('gpt-4o')
    end

    it 'promotes simulator_model and question_model onto their own columns' do
      run = described_class.start!(
        experiment:, triggered_by: 'operator',
        run_time_overrides: { 'question_model' => 'gpt-4o' }
      )
      expect(run.simulator_model).to eq('gpt-4o-mini')
      expect(run.question_model).to eq('gpt-4o')
    end

    it 'stores a 16-character configuration_digest' do
      run = described_class.start!(experiment:, triggered_by: 'operator')
      expect(run.configuration_digest).to match(/\A[0-9a-f]{16}\z/)
    end

    it 'produces the same digest for two runs with identical effective configuration' do
      run_a = described_class.start!(experiment:, triggered_by: 'operator')
      run_b = described_class.start!(experiment:, triggered_by: 'operator')
      expect(run_a.configuration_digest).to eq(run_b.configuration_digest)
    end

    it 'starts in queued status' do
      run = described_class.start!(experiment:, triggered_by: 'operator')
      expect(run.status).to eq('queued')
    end

    it 'refuses to start a run with a disallowed run-time override' do
      expect {
        described_class.start!(
          experiment:, triggered_by: 'operator',
          run_time_overrides: { 'use_kg_context' => true }
        )
      }.to raise_error(EvaluationConfiguration::OverrideValidationError)
      expect(described_class.where(evaluation_experiment: experiment).count).to eq(0)
    end

    it 'refuses to start a run whose experiment already has a disallowed override' do
      bad_experiment = create(
        :evaluation_experiment,
        name: 'bad-experiment', configuration_overrides: { 'use_facts_vec' => true },
      )
      expect {
        described_class.start!(experiment: bad_experiment, triggered_by: 'operator')
      }.to raise_error(EvaluationConfiguration::OverrideValidationError)
    end
  end
end
