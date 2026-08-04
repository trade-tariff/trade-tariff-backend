class EvaluationExperiment < Sequel::Model(Sequel[:evaluation_experiments].qualify(:uk))
  one_to_many :evaluation_runs, key: :experiment_id

  def validate
    super
    errors.add(:name, 'cannot be blank') if name.nil? || name.strip.empty?
    return if name.nil?

    duplicate = EvaluationExperiment.where(name:)
    duplicate = duplicate.exclude(id:) if id
    errors.add(:name, 'must be unique') if duplicate.any?
  end
end
