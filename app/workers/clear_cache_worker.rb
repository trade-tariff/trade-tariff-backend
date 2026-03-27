class ClearCacheWorker
  include Sidekiq::Worker

  sidekiq_options queue: :sync, retry: false

  def perform
    clear_backend_cache

    clear_frontend_cache

    ActiveSupport::Notifications.instrument(
      TradeTariffBackend::TariffUpdateEventListener::TARIFF_CACHE_CLEARED,
      service: TradeTariffBackend.service,
    )

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
    preserved = preserve_keys

    Rails.logger.info 'Clearing Rails cache'
    Rails.cache.clear
    Rails.logger.info 'Clearing Rails cache completed'

    Rails.logger.info 'Restoring preserved keys'
    restore_keys(preserved)
  end

  def preserve_keys
    prefixes = [
      Api::User::ActiveCommoditiesService::MYOTT_ALL_ACTIVE_COMMODITIES_CACHE_KEY,
      Api::User::ActiveCommoditiesService::MYOTT_ALL_EXPIRED_COMMODITIES_CACHE_KEY,
      CachedCommodityDescriptionService::CACHE_PREFIX,
    ]

    Rails.cache.redis.with do |redis|
      namespace = Rails.cache.options[:namespace]
      prefixes.each_with_object({}) do |prefix, preserved|
        pattern = namespace ? "#{namespace}:#{prefix}*" : "#{prefix}*"
        redis.scan_each(match: pattern) do |key|
          value = redis.get(key)
          ttl = redis.ttl(key)
          preserved[key] = { value: value, ttl: ttl }
        end
      end
    end
  end

  def restore_keys(preserved)
    Rails.cache.redis.with do |redis|
      preserved.each do |key, data|
        value = data[:value]
        ttl = data[:ttl]

        if ttl.positive?
          redis.set(key, value, ex: ttl)
        else
          # TTL is -1 (no expiry) or -2 (key doesn't exist)
          redis.set(key, value)
        end
      end
    end

    Rails.logger.info "Restored #{preserved.size} preserved keys"
  end
end
