class DownloadWorker
  include Sidekiq::Worker

  sidekiq_options queue: :rollbacks, retry: false

  def perform
    if TradeTariffBackend.use_cds?
      TariffSynchronizer.download_cds
    else
      TariffSynchronizer.download
    end
  end
end
