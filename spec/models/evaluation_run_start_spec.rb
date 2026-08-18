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
      run = described_class.start!(experiment:, triggered_by: 'operator', idempotency_key: SecureRandom.uuid)
      expect(run.effective_configuration['simulator_model']).to eq('gpt-4o-mini')
    end

    it 'stores the idempotency_key it was started with' do
      key = SecureRandom.uuid
      run = described_class.start!(experiment:, triggered_by: 'operator', idempotency_key: key)
      expect(run.idempotency_key).to eq(key)
    end

    it 'applies run-time overrides on top of the experiment overrides' do
      run = described_class.start!(
        experiment:, triggered_by: 'operator', idempotency_key: SecureRandom.uuid,
        run_time_overrides: { 'simulator_model' => 'gpt-4o' }
      )
      expect(run.effective_configuration['simulator_model']).to eq('gpt-4o')
    end

    it 'promotes simulator_model and question_model onto their own columns' do
      run = described_class.start!(
        experiment:, triggered_by: 'operator', idempotency_key: SecureRandom.uuid,
        run_time_overrides: { 'question_model' => 'gpt-4o' }
      )
      expect(run.simulator_model).to eq('gpt-4o-mini')
      expect(run.question_model).to eq('gpt-4o')
    end

    it 'stores a 16-character configuration_digest' do
      run = described_class.start!(experiment:, triggered_by: 'operator', idempotency_key: SecureRandom.uuid)
      expect(run.configuration_digest).to match(/\A[0-9a-f]{16}\z/)
    end

    it 'produces the same digest for two separately-keyed runs with identical effective configuration' do
      run_a = described_class.start!(experiment:, triggered_by: 'operator', idempotency_key: SecureRandom.uuid)
      run_b = described_class.start!(experiment:, triggered_by: 'operator', idempotency_key: SecureRandom.uuid)
      expect(run_a.id).not_to eq(run_b.id)
      expect(run_a.configuration_digest).to eq(run_b.configuration_digest)
    end

    it 'starts in queued status' do
      run = described_class.start!(experiment:, triggered_by: 'operator', idempotency_key: SecureRandom.uuid)
      expect(run.status).to eq('queued')
    end

    it 'refuses to start a run with a disallowed run-time override' do
      expect {
        described_class.start!(
          experiment:, triggered_by: 'operator', idempotency_key: SecureRandom.uuid,
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
        described_class.start!(experiment: bad_experiment, triggered_by: 'operator', idempotency_key: SecureRandom.uuid)
      }.to raise_error(EvaluationConfiguration::OverrideValidationError)
    end

    it 'returns the existing run instead of creating a second one when the idempotency_key repeats' do
      key = SecureRandom.uuid
      first_run = described_class.start!(experiment:, triggered_by: 'operator', idempotency_key: key)

      second_run = described_class.start!(experiment:, triggered_by: 'operator', idempotency_key: key)

      expect(second_run.id).to eq(first_run.id)
      expect(described_class.where(evaluation_experiment: experiment).count).to eq(1)
    end

    it 'returns the racing request run instead of raising when a concurrent create wins the unique-constraint race' do
      racing_run = create(
        :evaluation_run, evaluation_experiment: experiment, triggered_by: 'operator', idempotency_key: 'race-key',
                         configuration_digest: EvaluationConfiguration::DigestCalculator.call(
                           EvaluationConfiguration::Merger.call(EvaluationConfiguration::BaselineProvider.call, experiment.configuration_overrides),
                         )
      )
      allow(described_class).to receive(:find_by_idempotency_key).and_return(nil, racing_run)
      allow(described_class).to receive(:create).and_raise(Sequel::UniqueConstraintViolation.new('duplicate key'))

      result = described_class.start!(experiment:, triggered_by: 'operator', idempotency_key: 'race-key')

      expect(result).to eq(racing_run)
    end

    it 'raises IdempotencyKeyConflict instead of returning the wrong run when the key repeats with a different experiment' do
      key = SecureRandom.uuid
      described_class.start!(experiment:, triggered_by: 'operator', idempotency_key: key)
      other_experiment = create(:evaluation_experiment, name: 'other-experiment')

      expect {
        described_class.start!(experiment: other_experiment, triggered_by: 'operator', idempotency_key: key)
      }.to raise_error(EvaluationRun::IdempotencyKeyConflict, /experiment_id/)
    end

    it 'raises IdempotencyKeyConflict instead of returning the wrong run when the key repeats with a different triggered_by' do
      key = SecureRandom.uuid
      described_class.start!(experiment:, triggered_by: 'operator', idempotency_key: key)

      expect {
        described_class.start!(experiment:, triggered_by: 'scheduler', idempotency_key: key)
      }.to raise_error(EvaluationRun::IdempotencyKeyConflict, /triggered_by/)
    end

    it 'raises IdempotencyKeyConflict instead of returning the wrong run when the key repeats with different run-time overrides' do
      key = SecureRandom.uuid
      described_class.start!(experiment:, triggered_by: 'operator', idempotency_key: key)

      expect {
        described_class.start!(
          experiment:, triggered_by: 'operator', idempotency_key: key,
          run_time_overrides: { 'simulator_model' => 'gpt-4o' }
        )
      }.to raise_error(EvaluationRun::IdempotencyKeyConflict, /configuration/)
    end

    it 'raises IdempotencyKeyConflict instead of returning the wrong run when a racing request actually differs' do
      key = SecureRandom.uuid
      racing_run = create(:evaluation_run, evaluation_experiment: experiment, triggered_by: 'scheduler', idempotency_key: key)
      allow(described_class).to receive(:find_by_idempotency_key).and_return(nil, racing_run)
      allow(described_class).to receive(:create).and_raise(Sequel::UniqueConstraintViolation.new('duplicate key'))

      expect {
        described_class.start!(experiment:, triggered_by: 'operator', idempotency_key: key)
      }.to raise_error(EvaluationRun::IdempotencyKeyConflict, /triggered_by/)
    end
  end
end
