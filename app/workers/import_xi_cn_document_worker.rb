require_relative '../lib/xi_cn_importer/instrumentation'
require_relative '../lib/xi_cn_importer/logger'

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
    failed_count   = results.count { |r| r.status == :failed }

    XiCnImporter::Instrumentation.import_run_completed(
      imported: imported_count,
      failed: failed_count,
      duration_ms:,
    )

    notify_completed(results)
    notify_update_recipients(results)
  rescue StandardError => e
    XiCnImporter::Instrumentation.import_run_failed(
      error_class: e.class.name,
      error_message: e.message,
    )
    notify_failed(e)
    raise
  end

private

  def notify_update_recipients(results)
    results.select { |r| r.status == :imported }.each do |result|
      CustomsTariffUpdateNotifierService.new(result.celex).call
    rescue StandardError => e
      Rails.logger.error(
        "customs_tariff_update_notifier_failed: celex=#{result.celex} error_class=#{e.class.name} error_message=#{e.message}",
      )
      notify_slack(
        'XI Combined Nomenclature document import succeeded, but sending the update notification failed for ' \
        "CELEX ID #{result.celex}. #{e.class}: #{e.message}",
      )
    end
  end

  def notify_completed(results)
    imported = results.select { |r| r.status == :imported }
    failed   = results.select { |r| r.status == :failed }

    if imported.empty? && failed.empty?
      notify_slack('XI Combined Nomenclature document import completed. Nothing new to import.')
      return
    end

    lines = []
    imported.each { |r| lines << "  • CELEX ID: #{r.celex} ✓" }
    failed.each   { |r| lines << "  • CELEX ID: #{r.celex} ✗ #{r.error}" }

    counts = []
    counts << "imported: #{imported.count}" if imported.any?
    counts << "failed: #{failed.count}" if failed.any?

    status = failed.any? ? 'completed with failures' : 'completed'
    header = "XI Combined Nomenclature document import #{status}. #{counts.join(', ')}"

    notify_slack([header, *lines].join("\n"))
  end

  def notify_failed(error)
    notify_slack("XI Combined Nomenclature document import failed. #{error.class}: #{error.message}")
  end

  def notify_slack(message)
    SlackNotifierService.call(message)
  rescue StandardError => e
    Rails.logger.error(
      "Failed to send XI CN document import Slack notification: #{e.class}: #{e.message}",
    )
  end
end
