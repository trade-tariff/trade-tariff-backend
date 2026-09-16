# frozen_string_literal: true

class SearchAnalyticsSnapshotWorker
  include Sidekiq::Worker

  sidekiq_options queue: :within_1_day, retry: false, slack_channel: TradeTariffBackend.slack_observability_channel

  def perform(reporting_date = nil)
    # Jobs queued before the daily switch carry rolling-period arrays.
    reporting_date = nil if reporting_date.is_a?(Array)
    date = reporting_date ? Date.iso8601(reporting_date) : Time.current.utc.to_date - 1
    SearchAnalyticsQueryWorker.enqueue_day(
      reporting_date: date, region: ENV.fetch('AWS_REGION', ENV.fetch('AWS_DEFAULT_REGION', 'eu-west-2')),
    )
  end
end
