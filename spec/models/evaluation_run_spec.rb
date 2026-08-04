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
end
