class EvaluationRun < Sequel::Model(Sequel[:evaluation_runs].qualify(:uk))
  plugin :validation_helpers

  STATUSES = %w[queued running completed partially_failed failed cancelled].freeze

  many_to_one :evaluation_experiment, key: :experiment_id
  one_to_many :evaluation_results, key: :run_id

  def validate
    super
    validates_includes STATUSES, :status
    validates_presence :experiment_id
  end

  # idempotency_key makes retrying a create request safe: the caller generates one key
  # per logical "start this run" attempt and resends the same value on any retry, so a
  # repeat request returns the run already created instead of inserting a duplicate.
  # The rescue covers the race where two requests carrying the same key both pass the
  # lookup below before either has inserted — the loser returns the winner's row instead
  # of raising.
  def self.start!(experiment:, triggered_by:, idempotency_key:, run_time_overrides: {})
    existing = find_by_idempotency_key(idempotency_key)
    return existing if existing

    overrides = EvaluationConfiguration::Merger.call(experiment.configuration_overrides, run_time_overrides)
    EvaluationConfiguration::AllowlistValidator.call(overrides)

    baseline = EvaluationConfiguration::BaselineProvider.call
    effective_configuration = EvaluationConfiguration::Merger.call(baseline, overrides)
    digest = EvaluationConfiguration::DigestCalculator.call(effective_configuration)

    create(
      evaluation_experiment: experiment,
      status: 'queued',
      triggered_by:,
      configuration_digest: digest,
      effective_configuration:,
      question_model: effective_configuration['question_model'],
      simulator_model: effective_configuration['simulator_model'],
      idempotency_key:,
    )
  rescue Sequel::UniqueConstraintViolation
    find_by_idempotency_key(idempotency_key) || raise
  end

  def self.find_by_idempotency_key(idempotency_key)
    where(idempotency_key:).first
  end

  def reconcile_aggregates!
    results = evaluation_results_dataset

    update(
      result_count: results.count,
      error_count: results.exclude(error: nil).count,
      total_cost_usd: results.sum(:cost_usd) || 0,
      total_latency_seconds: results.sum(:latency_seconds) || 0,
    )
  end
end
