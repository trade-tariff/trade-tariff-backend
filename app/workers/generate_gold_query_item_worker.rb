# Generates the three gold queries (one per persona) for one source item of a gold query
# set, then counts the item in the set's progress. The set is finished, and its status
# set, when every planned item has been counted (see EvaluationGoldQuerySet.record_item_result).
class GenerateGoldQueryItemWorker
  include Sidekiq::Worker

  sidekiq_options queue: :within_1_day, retry: 3, slack_alerts: false

  # Sidekiq has given up on this item. Count it as failed, so the set can still finish.
  sidekiq_retries_exhausted do |job, exception|
    set_id, source_type, source_id = job['args']

    EvaluationGoldQuerySet.record_item_result(
      set_id,
      failure: {
        'source_type' => source_type,
        'source_id' => source_id,
        'error' => "#{exception.class}: #{exception.message}".truncate(500),
      },
    )
  end

  def perform(set_id, source_type, source_id)
    return unless TradeTariffBackend.uk?

    set = EvaluationGoldQuerySet[set_id]
    return unless set # The set was deleted while this job waited in the queue.

    source = Evaluation::GoldQuerySource.for(source_type:, source_id:)
    return record_failure(set, source_type, source_id, 'the source item no longer exists') unless source

    if Evaluation::GoldQueryGenerator.call(source, set:)
      EvaluationGoldQuerySet.record_item_result(set.id)
    else
      record_failure(set, source_type, source_id, 'the model did not return acceptable phrases after 3 attempts')
    end
  end

private

  def record_failure(set, source_type, source_id, error)
    EvaluationGoldQuerySet.record_item_result(
      set.id,
      failure: { 'source_type' => source_type, 'source_id' => source_id, 'error' => error },
    )
  end
end
