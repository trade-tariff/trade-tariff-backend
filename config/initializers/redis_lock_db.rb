module RedisLockDb
  class << self
    def redis
      Sidekiq.redis_pool
    end
  end
end

module RedlockEvalShaFix
  def lock(resource, val, ttl, allow_new_lock)
    recover_from_script_flush do
      @redis.with do |conn|
        conn.evalsha Redlock::Scripts::LOCK_SCRIPT_SHA, [resource], [val, ttl, allow_new_lock]
      end
    end
  rescue Redis::BaseConnectionError
    false
  end

  # rubocop:disable Style/RescueStandardError
  def unlock(resource, val)
    recover_from_script_flush do
      @redis.with do |conn|
        conn.evalsha Redlock::Scripts::UNLOCK_SCRIPT_SHA, [resource], [val]
      end
    end
  rescue
    # Nothing to do, unlocking is just a best-effort attempt.
  end
  # rubocop:enable Style/RescueStandardError
end

Redlock::Client::RedisInstance.prepend RedlockEvalShaFix
