class SynchronizerCheckWorker
  include Sidekiq::Worker

  # Sentinel value recorded when no applied updates exist at all, ensuring
  # the NR alert condition fires immediately rather than silently passing.
  NO_SYNC_SENTINEL_MINUTES = 99_999

  # TARIC (XI) publishes no updates on Sunday, Monday or Tuesday, so the sync
  # age is expected to be elevated on those days. We record the flag so the NR
  # alert condition can filter these periods out rather than paging on-call.
  XI_NO_UPDATE_DAYS = [0, 1, 2].freeze # Sunday, Monday, Tuesday

  def perform
    last_applied_at = TariffSynchronizer::BaseUpdate.most_recent_applied&.applied_at
    age_minutes = age_in_minutes(last_applied_at)

    NewRelic::Agent.record_custom_event(
      'TariffSyncAge',
      service: service,
      age_minutes: age_minutes,
      expected_stale: expected_stale?,
    )
  end

private

  def age_in_minutes(last_applied_at)
    return NO_SYNC_SENTINEL_MINUTES if last_applied_at.nil?

    (Time.zone.now - last_applied_at) / 60.0
  end

  def expected_stale?
    TradeTariffBackend.xi? && XI_NO_UPDATE_DAYS.include?(Time.zone.now.wday)
  end

  def service
    TradeTariffBackend.uk? ? 'uk' : 'xi'
  end
end
