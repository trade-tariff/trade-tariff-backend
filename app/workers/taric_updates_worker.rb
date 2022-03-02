class TaricUpdatesWorker
  include Sidekiq::Worker

  sidekiq_options queue: :sync, retry: false

  def perform
    logger.info 'Running TaricUpdatesWorker'
    logger.info 'Downloading...'

    TaricSynchronizer.download

    logger.info 'Applying...'

    TaricSynchronizer.apply(reindex_all_indexes: true)
  end
end
