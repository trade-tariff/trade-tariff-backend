module TradeTariffBackend
  module Config
    module Redis
      def redis_config
        db = Rails.env.test? ? test_redis_db : 0
        { url: ENV['REDIS_URL'], db:, id: nil }
      end

      def sidekiq_redis_config
        db = Rails.env.test? ? test_redis_db : 0
        {
          url: ENV.fetch('SIDEKIQ_REDIS_URL', ENV['REDIS_URL']),
          db:,
          id: nil,
          timeout: 5,
          reconnect_attempts: [0.1, 0.5, 1.0],
        }
      end

      def frontend_redis_url
        ENV.fetch('FRONTEND_REDIS_URL', 'redis://host.docker.internal:6379')
      end

      def test_redis_db
        ENV.fetch('TEST_ENV_NUMBER', '').to_i + 1
      end
    end
  end
end
