module RedisLockDb
  DEFAULT_POOL_SIZE = 10

  class << self
    delegate :logger, to: Rails
    attr_writer :redis

    def redis
      @redis ||= build_connection_pool
    end

  private

    def pool_size
      if Sidekiq.server?
        Sidekiq.options[:concurrency] || DEFAULT_POOL_SIZE
      else
        Integer(ENV['RAILS_MAX_THREADS'].presence || ENV['MAX_THREADS'].presence || DEFAULT_POOL_SIZE)
      end
    end

    def build_connection_pool
      logger.info "Initialising Redlock connection pool with #{pool_size} connections"

      ConnectionPool.new(size: pool_size) do
        Redis.new PaasConfig.redis
      end
    end
  end
end
