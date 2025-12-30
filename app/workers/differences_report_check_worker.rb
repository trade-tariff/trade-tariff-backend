class DifferencesReportCheckWorker
  include Sidekiq::Worker

  sidekiq_options retry: 1, retry_in: 1.hour

  def perform
    return unless TradeTariffBackend.environment.production?
    return unless TradeTariffBackend.uk?

    last_log = DifferencesLog.max(:date)

    return notify if last_log.blank?

    notify if last_log < 7.days.ago
  end

  private

  def notify
    SlackNotifierService.call(
      'The differences report has not run this week. Please check the differences report and run it.',
    )
  end
end
