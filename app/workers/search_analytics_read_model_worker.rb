# frozen_string_literal: true

class SearchAnalyticsReadModelWorker
  include Sidekiq::Worker

  sidekiq_options queue: :within_1_day, retry: false, slack_channel: TradeTariffBackend.slack_observability_channel

  def perform
    region = ENV.fetch('AWS_REGION', ENV.fetch('AWS_DEFAULT_REGION', 'eu-west-2'))
    # Explicitly building the first generation opts this service into maintenance.
    # An unused read model must not start bulk database work automatically.
    return unless SearchAnalyticsReadModel.latest(service: TradeTariffBackend.service, region:)

    SearchAnalytics::ReadModelRefresh.call(region:)
  rescue Sequel::AdvisoryLockError
    logger.info('Search analytics read-model refresh already running; check again on the next schedule')
  end
end
