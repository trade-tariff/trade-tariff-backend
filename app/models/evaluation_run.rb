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
  # key reused with a DIFFERENT experiment/triggered_by/run_time_overrides raises
  # IdempotencyKeyConflict instead of silently returning the wrong run — the key is a
  # fingerprint of one specific request, not a bare token that returns whatever it last
  # pointed to.
  #
  # The reuse check compares ONLY the caller's literal request inputs — experiment_id,
  # triggered_by, and run_time_overrides exactly as sent — never effective_configuration
  # or configuration_digest. Those two are DERIVED from experiment.configuration_overrides
  # and the admin-config baseline (EvaluationConfiguration::BaselineProvider), both of
  # which an operator can edit at any time. A genuine retry — literally the same request,
  # resent because the first response was lost — must return the original run even if an
  # operator changed an unrelated admin setting in the meantime; comparing derived,
  # time-varying state would wrongly reject that retry. Because of this, the reuse check
  # runs BEFORE any configuration resolution, so a real replay does no config/baseline
  # work at all.
  #
  # The rescue covers the race where two requests carrying the same key both pass the
  # lookup below before either has inserted — the loser resolves against the winner's
  # row the same way the pre-insert lookup above would have.
  def self.start!(experiment:, triggered_by:, idempotency_key:, run_time_overrides: {})
    existing = find_by_idempotency_key(idempotency_key)
    return resolve_reused_key!(existing, idempotency_key:, experiment:, triggered_by:, run_time_overrides:) if existing

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
      run_time_overrides:,
    )
  rescue Sequel::UniqueConstraintViolation
    winner = find_by_idempotency_key(idempotency_key)
    raise unless winner

    resolve_reused_key!(winner, idempotency_key:, experiment:, triggered_by:, run_time_overrides:)
  end

  def self.find_by_idempotency_key(idempotency_key)
    where(idempotency_key:).first
  end

  # Returns `existing` if it was genuinely created by the same logical request (same
  # experiment, same triggered_by, same literal run_time_overrides — see start!'s comment
  # for why this compares literal request inputs rather than any derived configuration);
  # raises IdempotencyKeyConflict naming the mismatched field(s) otherwise.
  def self.resolve_reused_key!(existing, idempotency_key:, experiment:, triggered_by:, run_time_overrides:)
    mismatches = []
    mismatches << "experiment_id (existing=#{existing.experiment_id}, requested=#{experiment.id})" if existing.experiment_id != experiment.id
    mismatches << "triggered_by (existing=#{existing.triggered_by.inspect}, requested=#{triggered_by.inspect})" if existing.triggered_by != triggered_by
    # JSON.parse(...to_json), not a bare Hash#== against run_time_overrides directly:
    # existing.run_time_overrides is a plain, string-keyed Hash exactly as Postgres
    # round-tripped it through jsonb. The incoming run_time_overrides may be an
    # ActionController::Parameters-derived HashWithIndifferentAccess or contain Symbol
    # keys, either of which can compare unequal to a plain Hash even with identical
    # content. Round-tripping through the same JSON serialization jsonb itself uses
    # guarantees both sides are compared in the exact representation that would be
    # persisted, not an incidental Ruby object-equality quirk.
    normalised_requested = JSON.parse(run_time_overrides.to_json)
    if existing.run_time_overrides != normalised_requested
      mismatches << "run_time_overrides (existing=#{existing.run_time_overrides.inspect}, requested=#{normalised_requested.inspect})"
    end

    return existing if mismatches.empty?

    raise IdempotencyKeyConflict, "Idempotency-Key #{idempotency_key} was already used for a different request: #{mismatches.join('; ')}"
  end
  private_class_method :resolve_reused_key!

  # aggregate_metrics (jsonb) is deliberately NOT reconciled here. It was
  # designed to hold harness-specific summary numbers (recall_at_k, mrr,
  # gold_top1_after_qa rate) imported from the old kg.eval_runs/
  # kg.e2e_eval_runs tables by AI-1072 (not yet built) — it is not something
  # live AI-1073 runs compute. Confirmed via grep (2026-08-24): nothing in
  # this codebase writes aggregate_metrics anywhere; it stays `{}` on every
  # live run until AI-1072 exists, and even then only applies to imported
  # rows unless a future decision extends it to live runs too.
  def reconcile_aggregates!
    results = evaluation_results_dataset

    update(
      result_count: results.count,
      error_count: results.exclude(error: nil).count,
      total_cost_usd: results.sum(:cost_usd) || 0,
      total_latency_seconds: results.sum(:latency_seconds) || 0,
      total_provider_calls: results.sum(:provider_calls) || 0,
    )
  end
end
