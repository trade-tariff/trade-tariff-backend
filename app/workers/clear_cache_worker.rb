class ClearCacheWorker
  include Sidekiq::Worker

  sidekiq_options retry: false

  def perform
    logger.info 'Clearing Rails cache'
    Rails.cache.clear
    logger.info 'Clearing Rails cache completed'

    Sidekiq::Client.enqueue(PrecacheHeadingsWorker, Time.zone.today.to_formatted_s(:db))
    Sidekiq::Client.enqueue(PrewarmQuotaOrderNumbersWorker)
    Sidekiq::Client.enqueue(ReindexModelsWorker)
    Sidekiq::Client.enqueue(InvalidateCacheWorker)
  end
end
