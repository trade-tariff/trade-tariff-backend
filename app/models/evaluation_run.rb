class EvaluationRun < Sequel::Model(Sequel[:evaluation_runs].qualify(:uk))
  plugin :validation_helpers

  STATUSES = %w[queued running completed partially_failed failed cancelled].freeze

  IdempotencyKeyConflict = Class.new(StandardError)

  many_to_one :evaluation_experiment, key: :experiment_id
  one_to_many :evaluation_results, key: :run_id

  def validate
    super
    validates_includes STATUSES, :status
    validates_presence :experiment_id
  end

  # idempotency_key makes retrying a create request safe: the caller generates one key
  # per logical "start this run" attempt and resends the same value on any retry, so a
  # repeat request returns the run already created instead of inserting a duplicate. A
  # key reused with a DIFFERENT experiment/triggered_by/configuration raises
  # IdempotencyKeyConflict instead of silently returning the wrong run — the key is a
  # fingerprint of one specific request, not a bare token that returns whatever it last
  # pointed to.
  # The rescue covers the race where two requests carrying the same key both pass the
  # lookup below before either has inserted — the loser resolves against the winner's
  # row the same way the pre-insert lookup above would have.
  def self.start!(experiment:, triggered_by:, idempotency_key:, run_time_overrides: {})
    overrides = EvaluationConfiguration::Merger.call(experiment.configuration_overrides, run_time_overrides)
    EvaluationConfiguration::AllowlistValidator.call(overrides)

    baseline = EvaluationConfiguration::BaselineProvider.call
    effective_configuration = EvaluationConfiguration::Merger.call(baseline, overrides)
    digest = EvaluationConfiguration::DigestCalculator.call(effective_configuration)

    existing = find_by_idempotency_key(idempotency_key)
    return resolve_reused_key!(existing, idempotency_key:, experiment:, triggered_by:, digest:) if existing

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
    winner = find_by_idempotency_key(idempotency_key)
    raise unless winner

    resolve_reused_key!(winner, idempotency_key:, experiment:, triggered_by:, digest:)
  end

  def self.find_by_idempotency_key(idempotency_key)
    where(idempotency_key:).first
  end

  # Returns `existing` if it was genuinely created by the same logical request
  # (same experiment, same triggered_by, same resolved configuration); raises
  # IdempotencyKeyConflict naming the mismatched field(s) otherwise.
  def self.resolve_reused_key!(existing, idempotency_key:, experiment:, triggered_by:, digest:)
    mismatches = []
    mismatches << "experiment_id (existing=#{existing.experiment_id}, requested=#{experiment.id})" if existing.experiment_id != experiment.id
    mismatches << "triggered_by (existing=#{existing.triggered_by.inspect}, requested=#{triggered_by.inspect})" if existing.triggered_by != triggered_by
    mismatches << "configuration (existing digest=#{existing.configuration_digest}, requested digest=#{digest})" if existing.configuration_digest != digest

    return existing if mismatches.empty?

    raise IdempotencyKeyConflict, "Idempotency-Key #{idempotency_key} was already used for a different request: #{mismatches.join('; ')}"
  end
  private_class_method :resolve_reused_key!

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
