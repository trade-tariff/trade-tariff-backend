# Starts the generation of a gold query set: queues one GenerateGoldQueryItemWorker job
# per source item that GoldQuerySetCreator picked. Doing this in a job keeps the web
# request (or rake task) that created the set fast.
class GenerateGoldQuerySetWorker
  include Sidekiq::Worker

  # No retries. A retry after a partial push would queue some items twice and count them
  # twice. If this job fails, the set stays in "generating": delete it and create it again.
  sidekiq_options queue: :within_1_day, retry: 0, slack_alerts: false

  # items is a list of [source_type, source_id] pairs, for example [['atar', '600014988']].
  def perform(set_id, items)
    return unless TradeTariffBackend.uk?
    return unless EvaluationGoldQuerySet[set_id] # The set was deleted before this job ran.

    GenerateGoldQueryItemWorker.perform_bulk(items.map { |source_type, source_id| [set_id, source_type, source_id] })
  end
end
