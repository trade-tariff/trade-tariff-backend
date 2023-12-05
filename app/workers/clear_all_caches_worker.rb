class ClearAllCachesWorker
  include Sidekiq::Worker

  sidekiq_options queue: :rollbacks, retry: false

  def perform
    clear_backend_fragment_cache
    clear_frontend_fragment_cache
  end

  def clear_backend_fragment_cache
    Rails.logger.info 'Clearing backend cache'
    Rails.cache.clear
    Rails.logger.info 'Backend cache cleared'
  end

  def clear_frontend_fragment_cache
    Rails.logger.info 'Clearing frontend cache'
    TradeTariffBackend.frontend_redis.flushdb
    Rails.logger.info 'Frontend cache cleared'
  end
end
