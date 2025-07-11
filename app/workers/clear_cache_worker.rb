class ClearCacheWorker
  include Sidekiq::Worker

  sidekiq_options queue: :sync, retry: false

  def perform
    logger.info 'Clearing Rails cache'
    Rails.cache.clear
    logger.info 'Clearing Rails cache completed'

    Sidekiq::Client.enqueue(PrecacheHeadingsWorker, Time.zone.today.to_formatted_s(:db))
    Sidekiq::Client.enqueue(PrewarmQuotaOrderNumbersWorker)
    Sidekiq::Client.enqueue(ReindexModelsWorker)

    # NOTE: Make sure caches have been refreshed before invalidating the CDN
    #       otherwise we serve up stale responses.
    Sidekiq::Client.enqueue_in(1.minute, InvalidateCacheWorker)
  end
end
