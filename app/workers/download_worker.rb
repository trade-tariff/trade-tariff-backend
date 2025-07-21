class DownloadWorker
  include Sidekiq::Worker

  sidekiq_options queue: :sync, retry: false

  def perform
    if TradeTariffBackend.uk?
      CdsSynchronizer.download
    else
      TaricSynchronizer.download
    end
  end
end
