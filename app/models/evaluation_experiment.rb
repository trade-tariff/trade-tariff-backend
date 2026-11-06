class EvaluationExperiment < Sequel::Model(Sequel[:evaluation_experiments].qualify(:uk))
  plugin :validation_helpers
  plugin :dirty

  one_to_many :evaluation_runs, key: :experiment_id
  # The gold query set every run of this experiment is scored against. Optional here, but
  # the eval app refuses to start a run for an experiment that has none.
  many_to_one :evaluation_gold_query_set, key: :gold_query_set_id
  # The alternative to a gold query set (AI-1448): a frozen sample of synthetic ATaRs, used
  # verbatim with no persona rewrite. At most one of this and evaluation_gold_query_set is
  # ever set -- see the mutual-exclusion and locking checks in #validate below.
  many_to_one :evaluation_synthetic_input_set, key: :synthetic_input_set_id

  def validate
    super
    validates_presence :name
    validates_unique :name
    errors.add(:gold_query_set_id, 'does not exist') if gold_query_set_id && evaluation_gold_query_set.nil?
    errors.add(:synthetic_input_set_id, 'does not exist') if synthetic_input_set_id && evaluation_synthetic_input_set.nil?
    errors.add(:synthetic_input_set_id, 'cannot be set at the same time as a gold query set') if gold_query_set_id && synthetic_input_set_id
    validate_source_not_already_locked
  end

  # The set this experiment is scored against, for showing which one is in use: 'gold_query_set' or
  # 'synthetic_input_set', and its name. Both are nil until a set has been chosen. Loading a page of
  # experiments or runs eager-loads both associations, so this adds no query per row.
  def source_type
    return 'gold_query_set' if gold_query_set_id

    'synthetic_input_set' if synthetic_input_set_id
  end

  def source_name
    (evaluation_gold_query_set || evaluation_synthetic_input_set)&.name
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

private

  # Once either source column has ever been set, it is locked forever -- including being
  # cleared back to blank, and including setting the OTHER column for the first time (AI-1448).
  # The backend's own update action used to permit changing gold_query_set_id after creation,
  # even though the admin UI never exposed a way to do it; this closes that gap so an
  # experiment's source can never drift after it is chosen, for run-to-run and
  # experiment-to-experiment comparability. An operator who wants different test data creates
  # a new experiment instead.
  def validate_source_not_already_locked
    return unless source_locked?
    return unless column_changed?(:gold_query_set_id) || column_changed?(:synthetic_input_set_id)

    errors.add(:base, 'cannot change its gold query set or synthetic input set once one has been chosen')
  end

  # new? guards the very first choice: a brand new record's columns always read back as their
  # own current value here (there is no "before" yet), so without this a first-time choice at
  # creation would wrongly look already locked.
  def source_locked?
    return false if new?

    initial_value(:gold_query_set_id).present? || initial_value(:synthetic_input_set_id).present?
  end
end
