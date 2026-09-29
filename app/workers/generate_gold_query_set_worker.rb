# Starts the generation of a gold query set: queues one GenerateGoldQueryItemWorker job
# per source item that GoldQuerySetCreator picked. Doing this in a job keeps the web
# request (or rake task) that created the set fast.
class GenerateGoldQuerySetWorker
  include Sidekiq::Worker

  # No retries. A retry after a partial push would queue some items twice and count them
  # twice. If this job fails, sidekiq_retries_exhausted below marks the set failed at once
  # (retry: 0 means Sidekiq gives up after the very first attempt), so it never stays stuck
  # in "generating" with no item job behind it.
  sidekiq_options queue: :within_1_day, retry: 0, slack_alerts: false

  # Queueing the item jobs failed (for example Redis was briefly unreachable), so no item
  # job will ever count itself against this set. Mark it failed outright instead of leaving
  # it stuck in "generating" forever with nothing able to finish it.
  sidekiq_retries_exhausted do |job, exception|
    set_id, = job['args']
    set = EvaluationGoldQuerySet[set_id]
    next unless set

    set.update(
      status: 'failed',
      failed_count: set.planned_count,
      failures: [{ 'source_type' => nil, 'source_id' => nil, 'error' => "#{exception.class}: #{exception.message}".truncate(500) }],
    )
  end

  # items is a list of [source_type, source_id] pairs, for example [['atar', '600014988']].
  def perform(set_id, items)
    return unless TradeTariffBackend.uk?
    return unless EvaluationGoldQuerySet[set_id] # The set was deleted before this job ran.

    GenerateGoldQueryItemWorker.perform_bulk(items.map { |source_type, source_id| [set_id, source_type, source_id] })
  end
end
