class HealthcheckWorker
  include Sidekiq::Worker

  sidekiq_options queue: :healthcheck, retry: 1

  def perform
    Sidekiq.redis do |redis|
      redis.set(Healthcheck::SIDEKIQ_KEY, healthcheck_time)
    end
  end

  private

  def healthcheck_time
    Time.zone.now.utc.iso8601
  end
end
