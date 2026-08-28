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

    it 'applies a symbol-keyed run_time_overrides hash the same as a string-keyed one' do
      # A Rails-console caller naturally writes { question_model: 'gpt-5.6' } (symbol key).
      # experiment.configuration_overrides and the admin-config baseline are always
      # string-keyed (round-tripped through jsonb / AdminConfiguration), so without
      # normalizing run_time_overrides first, Merger#deep_merge's plain Hash#merge sees
      # 'question_model' and :question_model as two DIFFERENT keys -- the override never
      # actually replaces the baseline value, it just sits next to it unused, and
      # DigestCalculator#canonicalize's `keys.sort` on the resulting mixed-type hash
      # raises ArgumentError ("comparison of String with :question_model failed").
      run = described_class.start!(
        experiment:, triggered_by: 'operator', idempotency_key: SecureRandom.uuid,
        run_time_overrides: { question_model: 'gpt-5.6' }
      )
      expect(run.question_model).to eq('gpt-5.6')
      expect(run.effective_configuration['question_model']).to eq('gpt-5.6')
      expect(run.configuration_digest).to match(/\A[0-9a-f]{16}\z/)
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
      racing_run = create(:evaluation_run, evaluation_experiment: experiment, triggered_by: 'operator', idempotency_key: 'race-key')
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
      }.to raise_error(EvaluationRun::IdempotencyKeyConflict, /run_time_overrides/)
    end

    it 'returns the original run on retry even though the experiment configuration_overrides changed in between' do
      key = SecureRandom.uuid
      first_run = described_class.start!(experiment:, triggered_by: 'operator', idempotency_key: key)

      # Simulates an operator editing the experiment (PATCH .../experiments/:id) between
      # the original request and a retry of it — the retry itself sends the exact same
      # inputs (same experiment_id, same triggered_by, same run_time_overrides), so it
      # must still return the original run, not a conflict. Comparing anything DERIVED
      # from experiment.configuration_overrides (effective_configuration/digest) would
      # wrongly reject this, because that derived value has now changed underneath it.
      experiment.update(configuration_overrides: { 'simulator_model' => 'gpt-4o' })

      retried_run = described_class.start!(experiment: experiment.reload, triggered_by: 'operator', idempotency_key: key)

      expect(retried_run.id).to eq(first_run.id)
    end

    it 'returns the original run on retry even though the admin-config baseline changed in between, and never re-resolves it' do
      key = SecureRandom.uuid
      baseline_a = { 'rrf_k' => 60 }
      baseline_b = { 'rrf_k' => 120 }
      allow(EvaluationConfiguration::BaselineProvider).to receive(:call).and_return(baseline_a, baseline_b)

      first_run = described_class.start!(experiment:, triggered_by: 'operator', idempotency_key: key)
      retried_run = described_class.start!(experiment:, triggered_by: 'operator', idempotency_key: key)

      expect(retried_run.id).to eq(first_run.id)
      # Only the FIRST call should ever resolve a baseline — a genuine replay is detected
      # from literal request inputs alone and returns before touching the baseline at all.
      expect(EvaluationConfiguration::BaselineProvider).to have_received(:call).once
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
