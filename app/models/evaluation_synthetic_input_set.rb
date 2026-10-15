# A named, saved, frozen sample of synthetic ATaRs, used verbatim (no persona rewrite) as an
# experiment's alternative to a gold query set. Unlike a gold query set there is no background
# generation step: sampling is instant, so a set is fully built the moment it is created.
class EvaluationSyntheticInputSet < Sequel::Model(Sequel[:evaluation_synthetic_input_sets].qualify(:uk))
  plugin :validation_helpers

  one_to_many :evaluation_synthetic_input_set_items, key: :set_id

  def validate
    super
    validates_presence %i[name requested_size actual_size]
    validates_unique :name
    errors.add(:requested_size, 'must be greater than 0') if requested_size && requested_size <= 0
  end
end
