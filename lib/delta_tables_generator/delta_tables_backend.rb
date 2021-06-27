module DeltaTablesGenerator
  module DeltaTablesBackend
    class << self
      # Lock key used for DB locks to keep just one instance of synchronizer
      # running in cluster environment
      def db_lock_key
        'deltas-lock'
      end

      def with_redis_lock(lock_name = db_lock_key, &block)
        lock = Redlock::Client.new([RedisLockDb.redis])
        lock.lock!(lock_name, 5000, &block)
      end
    end
  end
end
