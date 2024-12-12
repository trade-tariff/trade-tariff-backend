class CdsSnapshotImportWorker
  include Sidekiq::Worker

  def perform
    return unless TradeTariffBackend.uk?

    logger.info 'Running CdsSnapshotImportWorker'

    logger.info 'Downloading...'
    CdsSnapshotSynchronizer.download
    # TODO: Check if the file downloaded


    logger.info 'Applying...'
    CdsSnapshotSynchronizer.apply

  rescue TariffSynchronizer::CdsUpdateDownloader::ListDownloadFailedError
    # TODO: reschedule
  end
end
