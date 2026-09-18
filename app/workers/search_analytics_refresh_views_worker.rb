# frozen_string_literal: true

# Retained so already-queued jobs still refresh. Collection no longer enqueues it.
class SearchAnalyticsRefreshViewsWorker
  include Sidekiq::Worker

  sidekiq_options queue: :within_1_day, retry: false, slack_channel: TradeTariffBackend.slack_observability_channel

  def perform(service = TradeTariffBackend.service, *_ignored)
    raise ArgumentError, 'Refresh belongs to a different service' unless service == TradeTariffBackend.service

    SearchAnalyticsQueryWorker.refresh_views!
  end
end
