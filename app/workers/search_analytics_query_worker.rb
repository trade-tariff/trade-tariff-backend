# frozen_string_literal: true

class SearchAnalyticsQueryWorker
  include Sidekiq::Worker

  sidekiq_options queue: :within_1_day, retry: false, slack_channel: TradeTariffBackend.slack_observability_channel

  MAX_CONCURRENT = 3
  LOCK_NAMESPACE = 1_287_000

  def self.enqueue_backfill(region:, days: 30, log_group_name: SearchAnalytics::DailyQuery::SEARCH_LOG_GROUP_NAME, force: false, now: Time.current)
    unless days.is_a?(Integer) && days.between?(1, SearchAnalytics::DateRange::MAX_DAYS)
      raise ArgumentError, "DAYS must be between 1 and #{SearchAnalytics::DateRange::MAX_DAYS}"
    end

    rejected = []
    jobs = days.times.filter_map do |offset|
      date = now.utc.to_date - 1 - offset
      collector = SearchAnalytics::DailyQuery.new(reporting_date: date, region:, log_group_name:, force:, now:)
      next unless collector.plan.value?('run')

      job_id = perform_async(date.iso8601, nil, region, log_group_name, force, TradeTariffBackend.service)
      rejected << date.iso8601 unless job_id
      job_id
    end
    raise "Could not enqueue search analytics days: #{rejected.join(', ')}" if rejected.any?

    refresh_views! if jobs.empty?
    jobs
  end

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

    refresh_views_if_complete(reporting_date:, region:, log_group_name:) if jobs.empty?
    jobs
  end

  def self.refresh_views_if_complete(reporting_date:, region:, log_group_name:)
    plan = SearchAnalytics::DailyQuery.new(reporting_date:, region:, log_group_name:).plan
    return if plan.value?('run')

    refresh_views!
  end

  def self.refresh_views!
    SearchAnalytics::MaterializedViews.refresh!(wait: true, only_if_populated: true)
  end

  def perform(date = nil, name = nil, region = nil, log_group_name = SearchAnalytics::DailyQuery::SEARCH_LOG_GROUP_NAME, force = false, service = TradeTariffBackend.service)
    # Jobs queued by the previous version put service before date.
    if %w[uk xi].include?(date)
      date, name, region, log_group_name, force, service = name, region, log_group_name, force, service == true, date
    end
    raise ArgumentError, 'Query job belongs to a different service' unless service == TradeTariffBackend.service

    reporting_date = date ? Date.iso8601(date) : Time.current.utc.to_date - 1
    region ||= ENV.fetch('AWS_REGION', ENV.fetch('AWS_DEFAULT_REGION', 'eu-west-2'))
    return self.class.enqueue_day(reporting_date:, region:, log_group_name:, force:) unless name

    # Stable lanes bound collecting jobs across processes sharing this database.
    # Waiting for a lane never resubmits a query. The result store rechecks its
    # fingerprint under its own lock, so duplicate queued jobs reuse successes.
    lane = Digest::SHA256.hexdigest([service, date, name].to_json).to_i(16) % MAX_CONCURRENT
    result = SearchAnalyticsQueryResult.db.with_advisory_lock(LOCK_NAMESPACE + lane, wait: true) do
      SearchAnalytics::DailyQuery.call(
        reporting_date:, region:, log_group_name:, queries: [name], force:,
      )
    end
    if SearchAnalytics::MaterializedViews::SOURCE_NAMES.include?(name)
      # These are the view inputs. An unrelated optional query failing must not
      # leave successfully replaced journey data stale indefinitely.
      self.class.refresh_views!
    else
      self.class.refresh_views_if_complete(reporting_date:, region:, log_group_name:)
    end
    result
  end
end
