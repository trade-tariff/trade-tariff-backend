class ClearCacheWorker
  include Sidekiq::Worker

  sidekiq_options queue: :sync, retry: false

  PRESERVED_CACHE_KEYS = %w[
    myott_all_active_commodities
    myott_all_expired_commodities
  ].freeze

  def perform
    clear_backend_cache

    # Clear frontend cache
    Rails.logger.info 'Clearing frontend cache'
    TradeTariffBackend.frontend_redis.flushdb
    Rails.logger.info 'Frontend cache cleared'

    Sidekiq::Client.enqueue(PrecacheHeadingsWorker, Time.zone.today.to_formatted_s(:db))
    Sidekiq::Client.enqueue(PrewarmQuotaOrderNumbersWorker)
    Sidekiq::Client.enqueue(ReindexModelsWorker)

    # NOTE: Make sure caches have been refreshed before invalidating the CDN
    #       otherwise we serve up stale responses.
    Sidekiq::Client.enqueue_in(1.minute, InvalidateCacheWorker)
  end

  private

  def clear_backend_cache
    preserved = Rails.cache.read_multi(*PRESERVED_CACHE_KEYS)

    logger.info 'Clearing Rails cache'
    Rails.cache.clear
    logger.info 'Clearing Rails cache completed'

    preserved.each { |key, value| Rails.cache.write(key, value) }
  end
end
