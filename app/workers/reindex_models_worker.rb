class ReindexModelsWorker
  include Sidekiq::Worker

  sidekiq_options retry: false

  def perform
    logger.info 'Reindexing models in Elastic Search...'
    TradeTariffBackend.reindex
    # Drops and completely recreates the index
    TradeTariffBackend.v2_search_client.reindex_all
    logger.info 'Reindexing of models completed'
  end
end
