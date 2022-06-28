class ReindexModelsWorker
  include Sidekiq::Worker

  sidekiq_options retry: false

  def perform
    logger.info 'Reindexing models in Elastic Search...'
    TradeTariffBackend.reindex
    TradeTariffBackend.v2_reindex
    logger.info 'Reindexing of models completed'
  end
end
