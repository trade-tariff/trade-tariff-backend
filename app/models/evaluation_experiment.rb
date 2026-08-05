class EvaluationExperiment < Sequel::Model(Sequel[:evaluation_experiments].qualify(:uk))
  plugin :validation_helpers

  one_to_many :evaluation_runs, key: :experiment_id

  def validate
    super
    validates_presence :name
    validates_unique :name
  end
end
