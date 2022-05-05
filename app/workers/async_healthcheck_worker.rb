class AsyncHealthcheckWorker
  include Sidekiq::Worker
  sidekiq_options queue: :healthcheck, retry: 2

  TTL = 1.month
  HEALTHCHECK_KEY = 'sidekiq-healthcheck'.freeze

  def perform
    Rails.cache.write(HEALTHCHECK_KEY, healthcheck_time, expires_in: TTL.from_now)
  end

  private

  def healthcheck_time
    Time.zone.now.utc.to_formatted_s(:db)
  end
end
