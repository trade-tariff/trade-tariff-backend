class ClearCacheWorker
  include Sidekiq::Worker

  sidekiq_options queue: :sync, retry: false

  def perform
    clear_backend_cache

    clear_frontend_cache

    Sidekiq::Client.enqueue(PrecacheHeadingsWorker, Time.zone.today.to_formatted_s(:db))
    Sidekiq::Client.enqueue(PrewarmQuotaOrderNumbersWorker)
    Sidekiq::Client.enqueue(ReindexModelsWorker)

    # NOTE: Make sure caches have been refreshed before invalidating the CDN
    #       otherwise we serve up stale responses.
    Sidekiq::Client.enqueue_in(1.minute, InvalidateCacheWorker)
  end

  private

  def clear_frontend_cache
    Rails.logger.info 'Clearing frontend cache'
    TradeTariffBackend.frontend_redis.flushdb
    Rails.logger.info 'Frontend cache cleared'
  end

  def clear_backend_cache
    preserved_keys = Api::User::ActiveCommoditiesService::MYOTT_ALL_ACTIVE_COMMODITIES_CACHE_KEY,
                     Api::User::ActiveCommoditiesService::MYOTT_ALL_EXPIRED_COMMODITIES_CACHE_KEY
    preserved = Rails.cache.read_multi(*preserved_keys)

    logger.info 'Clearing Rails cache'
    Rails.cache.clear
    logger.info 'Clearing Rails cache completed'

    preserved.each { |key, value| Rails.cache.write(key, value) }
  end
end
