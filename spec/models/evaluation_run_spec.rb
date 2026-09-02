require 'rails_helper'

RSpec.describe EvaluationRun do
  let(:experiment) { create(:evaluation_experiment) }

  it 'requires a valid status' do
    run = build(:evaluation_run, evaluation_experiment: experiment, status: 'bogus', triggered_by: 'operator')
    expect(run.valid?).to be false
    expect(run.errors[:status]).to be_present
  end

  it 'accepts every documented lifecycle status' do
    described_class::STATUSES.each do |status|
      run = build(:evaluation_run, evaluation_experiment: experiment, status:, triggered_by: 'operator')
      expect(run.valid?).to be(true), "expected #{status} to be valid: #{run.errors.full_messages}"
    end
  end

  it 'enforces experiment_id at the database level' do
    expect {
      described_class.db[:evaluation_runs].insert(
        status: 'queued', triggered_by: 'operator', effective_configuration: Sequel.pg_jsonb({}),
      )
    }.to raise_error(Sequel::NotNullConstraintViolation)
  end

  it 'rejects a nonexistent experiment_id at the database level' do
    expect {
      described_class.db[:evaluation_runs].insert(
        experiment_id: -1, status: 'queued', triggered_by: 'operator',
        effective_configuration: Sequel.pg_jsonb({})
      )
    }.to raise_error(Sequel::ForeignKeyConstraintViolation)
  end

  it 'refuses to delete an experiment that still has runs' do
    create(:evaluation_run, evaluation_experiment: experiment, status: 'queued', triggered_by: 'operator')

    # Postgres 18 reworded RESTRICT-action FK violation messages to
    # "violates RESTRICT setting of foreign key constraint" (was "violates
    # foreign key constraint" on 15/16/17). Sequel 5.106.0 classifies this
    # error by matching text against the raw message, so on 18 it falls back
    # to the generic Sequel::DatabaseError instead of the specific
    # Sequel::ForeignKeyConstraintViolation subclass. Both wordings still
    # contain "foreign key constraint", so assert on that plus the common
    # ancestor class rather than the version-dependent subclass.
    expect { experiment.destroy }.to raise_error(Sequel::DatabaseError, /foreign key constraint/)
  end

  it 'rejects a status outside the documented lifecycle at the database level' do
    expect {
      described_class.db[:evaluation_runs].insert(
        experiment_id: experiment.id, status: 'bogus', triggered_by: 'operator',
        effective_configuration: Sequel.pg_jsonb({})
      )
    }.to raise_error(Sequel::CheckConstraintViolation)
  end

  it 'enforces idempotency_key uniqueness at the database level' do
    described_class.db[:evaluation_runs].insert(
      experiment_id: experiment.id, status: 'queued', triggered_by: 'operator',
      effective_configuration: Sequel.pg_jsonb({}), idempotency_key: 'dupe-key'
    )

    expect {
      described_class.db[:evaluation_runs].insert(
        experiment_id: experiment.id, status: 'queued', triggered_by: 'operator',
        effective_configuration: Sequel.pg_jsonb({}), idempotency_key: 'dupe-key'
      )
    }.to raise_error(Sequel::UniqueConstraintViolation)
  end

  describe 'started_at' do
    it 'stays nil while a run is queued' do
      run = create(:evaluation_run, evaluation_experiment: experiment, status: 'queued', triggered_by: 'operator')
      expect(run.started_at).to be_nil
    end

    it 'is stamped with the current time when status transitions to running' do
      run = create(:evaluation_run, evaluation_experiment: experiment, status: 'queued', triggered_by: 'operator')

      travel_to Time.utc(2026, 8, 25, 9, 0, 0) do
        run.update(status: 'running')
      end

      expect(run.started_at).to eq(Time.utc(2026, 8, 25, 9, 0, 0))
    end

    it 'does not move once set, even if the run is saved again while running' do
      run = create(:evaluation_run, evaluation_experiment: experiment, status: 'queued', triggered_by: 'operator')
      run.update(status: 'running')
      first_started_at = run.started_at

      travel_to(first_started_at + 5.minutes) { run.update(error_summary: 'transient retry noted') }

      expect(run.started_at).to eq(first_started_at)
    end

    it 'is stamped on create when a run is created directly in the running status' do
      run = create(:evaluation_run, evaluation_experiment: experiment, status: 'running', triggered_by: 'operator')
      expect(run.started_at).not_to be_nil
    end

    it 're-stamps to the new time if a completed run is re-executed and transitions back to running' do
      # Nothing currently stops a caller from re-running an already-finished
      # run_id (execute_run.py calls update_run(status="running") unconditionally,
      # with no check on the run's current status). When that happens, started_at
      # must reflect the re-run's own start time, not the original run's -- a
      # stale started_at next to a fresh completed_at would misreport how long
      # the re-run actually took.
      run = create(:evaluation_run, evaluation_experiment: experiment, status: 'queued', triggered_by: 'operator')

      travel_to(Time.utc(2026, 8, 25, 9, 0, 0)) { run.update(status: 'running') }
      travel_to(Time.utc(2026, 8, 25, 9, 5, 0)) { run.update(status: 'completed') }
      travel_to(Time.utc(2026, 8, 26, 10, 0, 0)) { run.update(status: 'running') }

      expect(run.started_at).to eq(Time.utc(2026, 8, 26, 10, 0, 0))
    end
  end
end
