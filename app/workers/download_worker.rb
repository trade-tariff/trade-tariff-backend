class DownloadWorker
  include Sidekiq::Worker

  sidekiq_options queue: :sync, retry: false

  def perform
    Thread.current[:tariff_sync_run_id] = SecureRandom.uuid

    TariffSynchronizer::Instrumentation.sync_run_started(triggered_by: self.class.name)
    TariffSynchronizer::Instrumentation.download_started

    if TradeTariffBackend.uk?
      CdsSynchronizer.download
    else
      TaricSynchronizer.download
    end
  ensure
    Thread.current[:tariff_sync_run_id] = nil
  end
end
