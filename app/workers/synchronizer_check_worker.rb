class SynchronizerCheckWorker
  include Sidekiq::Worker

  # Sentinel value recorded when no applied updates exist at all, ensuring
  # the NR alert condition fires immediately rather than silently passing.
  NO_SYNC_SENTINEL_MINUTES = 99_999

  def perform
    last_applied_at = TariffSynchronizer::BaseUpdate.most_recent_applied&.applied_at
    age_minutes = age_in_minutes(last_applied_at)

    NewRelic::Agent.record_custom_event("TariffSyncAge", service: service, age_minutes: age_minutes)
  end

private

  def age_in_minutes(last_applied_at)
    return NO_SYNC_SENTINEL_MINUTES if last_applied_at.nil?

    (Time.zone.now - last_applied_at) / 60.0
  end

  def service
    TradeTariffBackend.uk? ? 'uk' : 'xi'
  end
end
