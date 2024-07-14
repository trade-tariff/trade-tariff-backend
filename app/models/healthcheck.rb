class Healthcheck
  include Singleton

  SIDEKIQ_KEY = 'sidekiq-healthcheck'.freeze
  SIDEKIQ_THRESHOLD = 90.minutes

  class << self
    delegate :check, :checkz, to: :instance
  end

  delegate :revision, to: TradeTariffBackend

  def checkz
    {
      git_sha1: current_revision,
    }
  end

  def check
    checks = {
      git_sha1: current_revision,
      sidekiq: sidekiq_healthy?,
      postgres: postgres_healthy?,
      redis: redis_healthy?,
      opensearch: opensearch_healthy?,
    }

    checks.merge(healthy: checks.values.all?)
  end

  def current_revision
    revision || Rails.env.to_s
  end

  def opensearch_healthy?
    TradeTariffBackend.opensearch_client.ping
  end

  def redis_healthy?
    Sidekiq.redis(&:ping) == 'PONG'
  end

  def postgres_healthy?
    Sequel::Model.db.test_connection
  end

  def sidekiq_healthy?
    if (healthcheck_time = read_last_sidekiq_healthcheck)
      Time.zone.parse(healthcheck_time) >= SIDEKIQ_THRESHOLD.ago
    else
      false
    end
  end

  def read_last_sidekiq_healthcheck
    Sidekiq.redis do |redis|
      redis.get(SIDEKIQ_KEY)
    end
  end
end
