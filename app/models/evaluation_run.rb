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

  def self.start!(experiment:, triggered_by:, run_time_overrides: {})
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
    )
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
