# frozen_string_literal: true

class SearchAnalyticsSnapshotWorker
  include Sidekiq::Worker

  sidekiq_options queue: :within_1_day, retry: true

  def perform(periods = SearchAnalytics::SnapshotRefresh::PERIODS)
    SearchAnalytics::SnapshotRefresh.new(periods:).call
  end
end
