class DownloadWorker
  include Sidekiq::Worker

  sidekiq_options queue: :sync, retry: false

  def perform
    Thread.current[:tariff_sync_run_id] = SecureRandom.uuid
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    TariffSynchronizer::Instrumentation.sync_run_started(triggered_by: self.class.name)
    TariffSynchronizer::Instrumentation.download_started

    if TradeTariffBackend.uk?
      CdsSynchronizer.download
    else
      TaricSynchronizer.download
    end

    duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
    TariffSynchronizer::Instrumentation.sync_run_completed(duration_ms:)
  rescue StandardError => e
    TariffSynchronizer::Instrumentation.sync_run_failed(
      phase: 'download',
      error_class: e.class.name,
      error_message: e.message,
    )
    raise
  ensure
    Thread.current[:tariff_sync_run_id] = nil
  end
end
