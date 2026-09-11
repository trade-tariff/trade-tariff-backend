class DifferencesReportWorker
  include Sidekiq::Worker

  # Written to DifferencesLog only once the whole report has been generated and
  # published. Every worksheet loader writes its own log row before it does any
  # work, so worksheet rows prove a run started, never that it finished.
  # DifferencesReportCheckWorker watches for this key alone.
  COMPLETION_KEY = 'differences_report_completed'.freeze

  # retry_in is not a Sidekiq option; sidekiq_retry_in is the supported way to
  # delay retries, giving a late report publication time to appear.
  sidekiq_options retry: 2

  sidekiq_retry_in { 1.hour.to_i }

  def perform(deliver_email = true)
    differences = generate_differences

    record_completion

    if deliver_email
      send_differences_email(differences)
    end
  end

private

  def generate_differences
    Reporting::Differences.generate
  end

  # Recorded after generation returns, so a crashed or retried run leaves no
  # marker. A rerun on the same day replaces the day's marker rather than
  # stacking rows.
  def record_completion
    DifferencesLog.where(key: COMPLETION_KEY, date: Time.zone.today).delete
    DifferencesLog.create(date: Time.zone.today, key: COMPLETION_KEY, value: Time.zone.now.iso8601)
  end

  def send_differences_email(differences)
    ReportsMailer.differences(differences).deliver_now
  end
end
