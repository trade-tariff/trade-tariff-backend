class RecacheModelsWorker
  include Sidekiq::Worker

  sidekiq_options queue: :default, retry: false

  def perform
    logger.info 'Running RecacheModelsWorker for populating measures calculation on a heading page'
    TradeTariffBackend.recache
    logger.info 'Recache complete!'
  end
end
