class SynchronizerCheckWorker
  include Sidekiq::Worker
  include ScheduledJobHeartbeat

  # Metric-only job; reruns every 30 minutes via scheduler — do not retry-storm.
  sidekiq_options retry: false

  AGE_METRIC_NAMESPACE = 'TradeTariff/TariffSync'.freeze

  # Sentinel value recorded when no applied updates exist at all, ensuring
  # the CloudWatch staleness alarm fires rather than silently passing.
  NO_SYNC_SENTINEL_MINUTES = 99_999

  # TARIC (XI) publishes no updates on Sunday, Monday or Tuesday, so the sync
  # age is expected to be elevated on those days. We send no age datapoint on
  # those days, so the CloudWatch alarm sees missing data and does not alert.
  XI_NO_UPDATE_DAYS = [0, 1, 2].freeze # Sunday, Monday, Tuesday

  def perform
    last_applied_at = TariffSynchronizer::BaseUpdate.most_recent_applied&.applied_at
    age_minutes = age_in_minutes(last_applied_at)

    record_age_metric(age_minutes) unless expected_stale?

    # Always record the heartbeat: the check ran, even on expected-stale days.
    record_heartbeat
  end

private

  def record_age_metric(age_minutes)
    Aws::CloudWatch::Client.new.put_metric_data(
      namespace: AGE_METRIC_NAMESPACE,
      metric_data: [{
        metric_name: 'AgeMinutes',
        value: age_minutes,
        unit: 'None',
        dimensions: [
          { name: 'Service', value: service },
          { name: 'Environment', value: ENV.fetch('ENVIRONMENT', 'local') },
        ],
      }],
    )
  rescue Aws::Errors::ServiceError => e
    Rails.logger.error("tariff_sync_age_metric_failed: #{e.class.name}: #{e.message}")
  end

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
