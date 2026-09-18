# frozen_string_literal: true

class SearchAnalyticsRefreshViewsWorker
  include Sidekiq::Worker

  sidekiq_options queue: :within_1_day, retry: false, slack_channel: TradeTariffBackend.slack_observability_channel

  def perform(service = TradeTariffBackend.service)
    raise ArgumentError, 'Refresh belongs to a different service' unless service == TradeTariffBackend.service

    # Initial population is an explicit rollout step, not new background work
    # for services that have not adopted the analytics views.
    return unless SearchAnalytics::MaterializedViews.ready?

    # Recheck freshness after acquiring the lock. Dropping a busy refresh could
    # lose the final source update committed while another refresh was running.
    SearchAnalytics::MaterializedViews.refresh!(wait: true)
  end
end
