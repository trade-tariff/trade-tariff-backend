class ReindexModelsWorker
  include Sidekiq::Worker

  sidekiq_options retry: false

  def perform
    logger.info 'Reindexing models in Elastic Search...'
    TradeTariffBackend.reindex_all
    logger.info 'Reindexing of models completed'
  end
end
