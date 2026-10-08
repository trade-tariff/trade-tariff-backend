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

  # The database deletes a set's gold queries itself (ON DELETE CASCADE), which skips the
  # model hooks that would write a 'destroy' version for each one. Their history is
  # therefore removed here instead, so the versions table is not left holding history for
  # rows that no longer exist. Sequel runs hooks inside the delete's transaction, so if
  # the delete is then refused (an experiment still uses the set) the history is kept.
  #
  # History is found by the set_id inside each version's snapshot, not by the ids of the
  # rows that exist now. Otherwise the history of an item that an operator deleted earlier
  # would be missed, because its rows are already gone.
  def before_destroy
    Version
      .where(item_type: EvaluationGoldQuery.name)
      .where(Sequel.lit("object ->> 'set_id' = ?", id.to_s))
      .delete

    super
  end

  # How many source items each set holds now, by source type:
  # { set_id => { 'atar' => 2, 'synthetic_atar' => 1 } }. A set with no gold queries is
  # left out. Rows are counted by DISTINCT source_id because every item has one row per
  # persona, so counting rows would triple the answer.
  def self.item_counts(set_ids)
    EvaluationGoldQuery
      .where(set_id: set_ids)
      .select_group(:set_id, :source_type)
      .select_append(Sequel.lit('COUNT(DISTINCT source_id)').as(:items))
      .each_with_object({}) do |row, counts|
        (counts[row[:set_id]] ||= {})[row[:source_type]] = row[:items]
      end
  end

  # How many gold query rows each set holds now — every item has one row per persona (see
  # item_counts above), and this is the real total a run of this set iterates over
  # (execute_run.py fetches every row, not one per item), unlike item_counts' deliberately
  # deduplicated "N items" figure.
  def self.gold_query_counts(set_ids)
    EvaluationGoldQuery
      .where(set_id: set_ids)
      .select_group(:set_id)
      .select_append(Sequel.lit('COUNT(*)').as(:count))
      .each_with_object({}) { |row, counts| counts[row[:set_id]] = row[:count] }
  end

  # Adds one finished item to the set's counters. Call it once per item, when that item
  # has either produced its gold queries (no failure) or definitely failed (pass the
  # failure, a hash of source_type, source_id and error, which is added to the list).
  #
  # It is a single UPDATE, so jobs finishing at the same moment cannot lose each other's
  # increments. The same UPDATE moves the status on once generated + failed reaches
  # planned_count, because there are no Sidekiq batch callbacks to do it: ready when
  # nothing failed, failed when everything failed, partly_failed otherwise.
  def self.record_item_result(id, failure: nil)
    generated_after = Sequel[:generated_count] + (failure ? 0 : 1)
    failed_after = Sequel[:failed_count] + (failure ? 1 : 0)
    finished = (generated_after + failed_after) >= Sequel[:planned_count]

    changes = {
      generated_count: generated_after,
      failed_count: failed_after,
      status: Sequel.case(
        [
          [finished & (failed_after =~ 0), 'ready'],
          [finished & (generated_after =~ 0), 'failed'],
          [finished, 'partly_failed'],
        ],
        Sequel[:status],
      ),
    }
    changes[:failures] = Sequel.lit('failures || ?::jsonb', [failure].to_json) if failure

    where(id:).update(changes)
  end
end
