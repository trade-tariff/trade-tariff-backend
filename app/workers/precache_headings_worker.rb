class PrecacheHeadingsWorker
  include Sidekiq::Worker

  # Precache is re-enqueued after cache clear; avoid Sidekiq default (25) retries.
  sidekiq_options queue: :sync, retry: 3

  def perform(date = nil)
    date = date ? Time.zone.parse(date).to_date : Time.zone.tomorrow

    HeadingService::PrecacheService.new(date).call
  end
end
