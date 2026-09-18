# frozen_string_literal: true

class SearchAnalyticsRefreshViewsWorker
  include Sidekiq::Worker

  sidekiq_options queue: :within_1_day, retry: false, slack_channel: TradeTariffBackend.slack_observability_channel

  FOLLOWUP_INTERVAL = 30
  FOLLOWUP_LEASE = 600
  FOLLOWUP_KEY_PREFIX = 'search_analytics:refresh_views:followup:'
  RELEASE_OWN_LEASE = <<~LUA
    if redis.call('GET', KEYS[1]) == ARGV[1] then
      return redis.call('DEL', KEYS[1])
    end
    return 0
  LUA

  def perform(service = TradeTariffBackend.service, token = nil)
    raise ArgumentError, 'Refresh belongs to a different service' unless service == TradeTariffBackend.service

    # Followup jobs own a scheduling lease, not a cached result. Release only that
    # token before running so a still-busy lock can schedule the next delay.
    self.class.release_followup(service, token) if token
    SearchAnalytics::MaterializedViews.refresh!(wait: false, only_if_populated: true)
  rescue Sequel::AdvisoryLockError
    self.class.schedule_followup(service)
  end

  def self.schedule_followup(service)
    token = SecureRandom.uuid
    acquired = Sidekiq.redis { |redis| redis.set(followup_key(service), token, nx: true, ex: FOLLOWUP_LEASE) }
    return unless acquired

    job_id = enqueue_followup(service, token)
    return job_id if job_id

    release_followup(service, token)
    raise 'Query results are stored, but the analytics view refresh could not be queued'
  end

  def self.release_followup(service, token)
    return unless token

    Sidekiq.redis { |redis| redis.call('EVAL', RELEASE_OWN_LEASE, 1, followup_key(service), token) }
  end

  def self.followup_key(service) = "#{FOLLOWUP_KEY_PREFIX}#{service}"

  def self.enqueue_followup(service, token)
    perform_in(FOLLOWUP_INTERVAL, service, token)
  rescue StandardError
    release_followup(service, token)
    raise
  end
end
