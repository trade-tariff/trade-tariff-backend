class UpdatesSynchronizerWorker
  include Sidekiq::Worker

  sidekiq_options queue: :sync, retry: false

  def perform
    logger.info 'Running UpdatesSynchronizerWorker'
    logger.info 'Downloading...'

    # TODO: this check can be removed when we switch to CDS data.
    if TradeTariffBackend.use_cds?
      TariffSynchronizer.download_cds
      logger.info 'Applying...'
      TariffSynchronizer.apply_cds
    elsif TradeTariffBackend.xi?
      TariffSynchronizer.download
      logger.info 'Applying...'
      TariffSynchronizer.apply
    end
  end
end
