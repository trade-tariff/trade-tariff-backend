module RedisLockDb
  class << self
    def redis= redis
      @redis = redis
    end

    def redis
      @redis ||= Sidekiq.redis { |conn| conn }
    end
  end
end
