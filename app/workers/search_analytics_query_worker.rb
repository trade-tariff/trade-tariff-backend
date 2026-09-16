# frozen_string_literal: true

class SearchAnalyticsQueryWorker
  include Sidekiq::Worker

  sidekiq_options queue: :within_1_day, retry: false, slack_channel: TradeTariffBackend.slack_observability_channel

  MAX_CONCURRENT = 3
  LOCK_NAMESPACE = 1_287_000

  def self.enqueue_day(reporting_date:, region:, log_group_name: SearchAnalytics::DailyQuery::SEARCH_LOG_GROUP_NAME, queries: nil, force: false)
    collector = SearchAnalytics::DailyQuery.new(reporting_date:, region:, log_group_name:, queries:, force:)
    rejected = []
    jobs = collector.plan.filter_map do |name, action|
      next unless action == 'run'

      job_id = perform_async(reporting_date.iso8601, name, region, log_group_name, force, TradeTariffBackend.service)
      rejected << name unless job_id
      job_id
    end
    raise "Could not enqueue search analytics queries: #{rejected.join(', ')}" if rejected.any?

    jobs
  end

  def perform(date = nil, name = nil, region = nil, log_group_name = SearchAnalytics::DailyQuery::SEARCH_LOG_GROUP_NAME, force = false, service = TradeTariffBackend.service)
    raise ArgumentError, 'Query job belongs to a different service' unless service == TradeTariffBackend.service

    reporting_date = date ? Date.iso8601(date) : Time.current.utc.to_date - 1
    region ||= ENV.fetch('AWS_REGION', ENV.fetch('AWS_DEFAULT_REGION', 'eu-west-2'))
    return self.class.enqueue_day(reporting_date:, region:, log_group_name:, force:) unless name

    # Stable lanes bound collecting jobs across processes sharing this database.
    # Waiting for a lane never resubmits a query. The result store rechecks its
    # fingerprint under its own lock, so duplicate queued jobs reuse successes.
    lane = Digest::SHA256.hexdigest([service, date, name].to_json).to_i(16) % MAX_CONCURRENT
    SearchAnalyticsQueryResult.db.with_advisory_lock(LOCK_NAMESPACE + lane, wait: true) do
      SearchAnalytics::DailyQuery.call(
        reporting_date:, region:, log_group_name:, queries: [name], force:,
      )
    end
  end
end
