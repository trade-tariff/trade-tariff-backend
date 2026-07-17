require_relative '../lib/customs_tariff_importer/instrumentation'
require_relative '../lib/customs_tariff_importer/logger'

class ImportCustomsTariffDocumentWorker
  include Sidekiq::Worker

  sidekiq_options queue: :default, retry: false, slack_alerts: false

  def perform
    return unless TradeTariffBackend.uk?

    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    CustomsTariffImporter::Instrumentation.import_run_started

    results = CustomsTariffImporter::Importer.new.call

    duration_ms    = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
    imported_count = results.count { |r| r.status == :imported }
    failed_count   = results.count { |r| r.status == :failed }

    CustomsTariffImporter::Instrumentation.import_run_completed(
      imported: imported_count,
      failed: failed_count,
      duration_ms:,
    )

    notify_completed(results)
  rescue StandardError => e
    CustomsTariffImporter::Instrumentation.import_run_failed(
      error_class: e.class.name,
      error_message: e.message,
    )
    notify_failed(e)
    raise
  end

private

  def notify_completed(results)
    imported = results.select { |r| r.status == :imported }
    failed   = results.select { |r| r.status == :failed }

    if imported.empty? && failed.empty?
      notify_slack('Customs tariff document import completed. Nothing new to import.')
      return
    end

    lines = []
    imported.each { |r| lines << "  • Version ID: #{r.version} ✓" }
    failed.each   { |r| lines << "  • Version ID: #{r.version} ✗ #{r.error}" }

    counts = []
    counts << "imported: #{imported.count}" if imported.any?
    counts << "failed: #{failed.count}" if failed.any?

    status = failed.any? ? 'completed with failures' : 'completed'
    header = "Customs tariff document import #{status}. #{counts.join(', ')}"

    notify_slack([header, *lines].join("\n"))
  end

  def notify_failed(error)
    notify_slack("Customs tariff document import failed. #{error.class}: #{error.message}")
  end

  def notify_slack(message)
    SlackNotifierService.call(message)
  rescue StandardError => e
    Rails.logger.error(
      "Failed to send customs tariff document import Slack notification: #{e.class}: #{e.message}",
    )
  end
end
