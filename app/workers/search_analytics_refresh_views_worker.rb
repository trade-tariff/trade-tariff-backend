# frozen_string_literal: true

class SearchAnalyticsRefreshViewsWorker
  include Sidekiq::Worker

  sidekiq_options queue: :within_1_day, retry: false, slack_channel: TradeTariffBackend.slack_observability_channel

  FOLLOWUP_INTERVAL = 30

  def perform(service = TradeTariffBackend.service, _token = nil)
    raise ArgumentError, 'Refresh belongs to a different service' unless service == TradeTariffBackend.service

    SearchAnalytics::MaterializedViews.refresh!(wait: false, only_if_populated: true)
  rescue Sequel::AdvisoryLockError
    self.class.schedule_followup(service)
  end

  def self.schedule_followup(service)
    job_id = perform_in(FOLLOWUP_INTERVAL, service)
    return job_id if job_id

    raise 'Query results are stored, but the analytics view refresh could not be queued'
  end
end
