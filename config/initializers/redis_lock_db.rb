module RedisLockDb
  class << self
    def redis
      Sidekiq.redis_pool
    end
  end
end
