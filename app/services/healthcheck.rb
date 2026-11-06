class Healthcheck
  include Singleton

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
    Sidekiq::ProcessSet.new.size.positive?
  end
end
