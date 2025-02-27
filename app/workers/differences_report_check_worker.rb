class DifferencesReportCheckWorker
  include Sidekiq::Worker

  sidekiq_options retry: 1, retry_in: 1.hour

  def perform
    return unless ENV.fetch('ENVIRONMENT', '') == 'production'

    last_log = DifferencesLog.max(:date)
    notify_failure if last_log < 7.days.ago
  end

  private

  def notify_failure
    SlackNotifierService.call('The differences report has not run this week. Please check the differences report and run it.')
  end
end
