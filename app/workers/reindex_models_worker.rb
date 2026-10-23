class ReindexModelsWorker
  include Sidekiq::Worker

  sidekiq_options queue: :within_1_minute, retry: false

  def perform
    logger.info 'Reindexing models in Elastic Search...'
    TradeTariffBackend.reindex
    logger.info 'Reindexing of models completed'
  end
end
