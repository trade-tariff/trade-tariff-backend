class DifferencesReportCheckWorker
  include Sidekiq::Worker

  sidekiq_options retry: 1, retry_in: 1.hour

  def perform
    return unless TradeTariffBackend.environment.production?
    return unless TradeTariffBackend.uk?

    # Only DifferencesReportWorker writes this key, and only once the report has
    # been generated and published. Worksheet log rows are deliberately ignored:
    # a run that crashed after writing 19 of 24 of them has not run the report.
    last_completion = DifferencesLog.where(key: DifferencesReportWorker::COMPLETION_KEY).max(:date)

    return notify if last_completion.blank?

    # Notify if the report hasn't completed this week
    notify if last_completion.before?(Date.current.beginning_of_week)
  end

private

  def notify
    SlackNotifierService.call(
      'The differences report has not run to completion this week. Please check the differences report and run it.',
    )
  end
end
