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
    CustomsTariffImporter::Instrumentation.import_run_completed(
      imported: results.count { |r| r.status == :imported },
      skipped: results.count { |r| %i[skipped duplicate_content].include?(r.status) },
      failed: results.count { |r| r.status == :failed },
      duration_ms:,
    )
  rescue StandardError => e
    CustomsTariffImporter::Instrumentation.import_run_failed(
      error_class: e.class.name,
      error_message: e.message,
    )
    raise
  end
end
