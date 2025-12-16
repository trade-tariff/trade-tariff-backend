module RedisLockDb
  class << self
    def redis
      # Sidekiq.redis_pool was removed in Sidekiq 7.0+ (connection_pool 3.0+)
      # Redlock needs a Redis configuration, ConnectionPool, or Redis client
      # We use TradeTariffBackend.redis_config which returns the Redis connection config
      TradeTariffBackend.redis_config
    end
  end
end
