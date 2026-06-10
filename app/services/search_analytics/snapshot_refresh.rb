# frozen_string_literal: true

module SearchAnalytics
  class SnapshotRefresh
    PERIODS = %w[24h 7d 30d].freeze
    VIEWS = %w[all classic internal].freeze

    def self.call(now: Time.current, periods: PERIODS)
      new(now:, periods:).call
    end

    def initialize(query_class: CloudwatchSnapshotQuery, now: Time.current, periods: PERIODS)
      @query_class = query_class
      @now = now
      @periods = periods
    end

    def call
      periods.flat_map do |period_key|
        payloads = query_class.call(period: period_key, now:)

        VIEWS.map { |view| refresh_snapshot(period_key, view, payloads.fetch(view)) }
      end
    end

    private

    attr_reader :query_class, :now, :periods

    def refresh_snapshot(period_key, view, payload)
      period = Period.for(period: period_key, view:)
      SearchAnalyticsSnapshot.create(
        service: TradeTariffBackend.service,
        period: period.key,
        view: period.view,
        bucket_size: period.bucket_size,
        generated_at: now,
        data_through: now,
        payload:,
      )
    end
  end
end
