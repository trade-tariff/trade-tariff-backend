class EvaluationExperiment < Sequel::Model(Sequel[:evaluation_experiments].qualify(:uk))
  plugin :validation_helpers

  one_to_many :evaluation_runs, key: :experiment_id
  # The gold query set every run of this experiment is scored against. Optional here, but
  # the eval app refuses to start a run for an experiment that has none.
  many_to_one :evaluation_gold_query_set, key: :gold_query_set_id

  def validate
    super
    validates_presence :name
    validates_unique :name
    errors.add(:gold_query_set_id, 'does not exist') if gold_query_set_id && evaluation_gold_query_set.nil?
  end

  # evaluation_runs.experiment_id is ON DELETE RESTRICT, so the database refuses this delete while any
  # runs exist. Neither EvaluationRun nor EvaluationResult has history (has_paper_trail), so — unlike
  # gold query set deletion — there is no version cleanup needed here, only the cascade itself.
  # evaluation_results.run_id is already ON DELETE CASCADE, so deleting the runs removes their results
  # for free.
  def before_destroy
    evaluation_runs_dataset.delete
    super
  end
end
