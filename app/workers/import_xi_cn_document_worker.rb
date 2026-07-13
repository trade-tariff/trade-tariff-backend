class ImportXiCnDocumentWorker
  include Sidekiq::Worker

  sidekiq_options queue: :default, retry: false, slack_alerts: false

  def perform
    return unless TradeTariffBackend.xi?

    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    XiCnImporter::Instrumentation.import_run_started

    results = XiCnImporter::Importer.new.call

    duration_ms    = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
    imported_count = results.count { |r| r.status == :imported }
    skipped_count  = results.count { |r| r.status == :skipped }
    failed_count   = results.count { |r| r.status == :failed }
    review_backlog = CustomsTariffUpdate.pending.count

    XiCnImporter::Instrumentation.import_run_completed(
      imported: imported_count,
      skipped: skipped_count,
      failed: failed_count,
      duration_ms:,
      review_backlog:,
    )

    notify_completed(imported_count:, skipped_count:, failed_count:, review_backlog:)
  rescue StandardError => e
    XiCnImporter::Instrumentation.import_run_failed(
      error_class: e.class.name,
      error_message: e.message,
    )
    notify_failed(e)
    raise
  end

  private

  def notify_completed(imported_count:, skipped_count:, failed_count:, review_backlog:)
    return unless imported_count.positive? || failed_count.positive?

    status = failed_count.positive? ? 'completed with failures' : 'completed'

    notify_slack(
      "XI CN document import #{status}. " \
      "imported: #{imported_count}, skipped: #{skipped_count}, failed: #{failed_count}, " \
      "pending review: #{review_backlog}",
    )
  end

  def notify_failed(error)
    notify_slack("XI CN document import failed. #{error.class}: #{error.message}")
  end

  def notify_slack(message)
    SlackNotifierService.call(message)
  rescue StandardError => e
    Rails.logger.error(
      "Failed to send XI CN document import Slack notification: #{e.class}: #{e.message}",
    )
  end
end
