require_relative '../lib/customs_tariff_importer/instrumentation'
require_relative '../lib/customs_tariff_importer/logger'

class ImportCustomsTariffDocumentWorker
  include Sidekiq::Worker

  sidekiq_options queue: :default, retry: false, slack_alerts: false

  def perform
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    CustomsTariffImporter::Instrumentation.import_run_started

    results = CustomsTariffImporter::Importer.new.call

    duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
    imported_count = results.count { |r| r.status == :imported }
    skipped_count = results.count { |r| %i[skipped duplicate_content].include?(r.status) }
    failed_count = results.count { |r| r.status == :failed }
    review_backlog = CustomsTariffUpdate.pending.count

    CustomsTariffImporter::Instrumentation.import_run_completed(
      imported: imported_count,
      skipped: skipped_count,
      failed: failed_count,
      duration_ms:,
      review_backlog:,
    )

    notify_completed(imported_count:, skipped_count:, failed_count:, review_backlog:)
  rescue StandardError => e
    CustomsTariffImporter::Instrumentation.import_run_failed(
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
      "Customs tariff document import #{status}. " \
      "imported: #{imported_count}, skipped: #{skipped_count}, failed: #{failed_count}, " \
      "pending review: #{review_backlog}",
    )
  end

  def notify_failed(error)
    notify_slack(
      "Customs tariff document import failed. #{error.class}: #{error.message}",
    )
  end

  def notify_slack(message)
    SlackNotifierService.call(message)
  rescue StandardError => e
    Rails.logger.error(
      "Failed to send customs tariff document import Slack notification: #{e.class}: #{e.message}",
    )
  end
end
