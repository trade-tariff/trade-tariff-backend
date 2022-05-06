class HealthcheckWorker
  include Sidekiq::Worker
  sidekiq_options queue: :healthcheck, retry: 2

  TTL = 1.month

  def perform
    Rails.cache.write(Healthcheck::SIDEKIQ_KEY,
                      healthcheck_time,
                      expires_in: TTL)
  end

  private

  def healthcheck_time
    Time.zone.now.utc.iso8601
  end
end
