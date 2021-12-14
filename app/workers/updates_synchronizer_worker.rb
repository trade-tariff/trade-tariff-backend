class UpdatesSynchronizerWorker
  include Sidekiq::Worker

  sidekiq_options queue: :sync, retry: false

  def perform
    logger.info 'Running UpdatesSynchronizerWorker'
    logger.info 'Downloading...'

    if TradeTariffBackend.uk?
      TariffSynchronizer.download_cds
      logger.info 'Applying...'
      TariffSynchronizer.apply_cds(reindex_all_indexes: true)
    elsif TradeTariffBackend.xi?
      TariffSynchronizer.download
      logger.info 'Applying...'
      TariffSynchronizer.apply(reindex_all_indexes: true)
    end
  end
end
