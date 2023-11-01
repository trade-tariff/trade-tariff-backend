class DownloadWorker
  include Sidekiq::Worker

  sidekiq_options queue: :rollbacks, retry: false

  def perform
    if TradeTariffBackend.use_cds?
      CdsSynchronizer.download
    else
      TaricSynchronizer.download
    end
  end
end
