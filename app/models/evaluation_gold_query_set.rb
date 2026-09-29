# A named, saved collection of gold queries. An experiment points at one set, so every run
# of that experiment is scored against the same queries and runs can be compared fairly.
#
# A set owns its gold query rows: editing a query in one set never changes another set.
class EvaluationGoldQuerySet < Sequel::Model(Sequel[:evaluation_gold_query_sets].qualify(:uk))
  STATUSES = %w[generating ready partly_failed failed].freeze
  # A cheap guard against a typo starting thousands of LLM calls.
  MAX_SIZE = 500

  plugin :validation_helpers

  one_to_many :evaluation_gold_queries, key: :set_id
  one_to_many :evaluation_experiments, key: :gold_query_set_id

  def validate
    super
    validates_presence %i[name requested_size atar_percentage planned_count status]
    validates_unique :name
    validates_includes STATUSES, :status, allow_nil: true
    validates_includes 1..MAX_SIZE, :requested_size, allow_nil: true, message: "must be between 1 and #{MAX_SIZE}"
    validates_includes 0..100, :atar_percentage, allow_nil: true, message: 'must be between 0 and 100'
  end
end
