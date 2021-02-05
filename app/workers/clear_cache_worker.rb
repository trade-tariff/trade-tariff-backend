class ClearCacheWorker
  include Sidekiq::Worker

  sidekiq_options retry: false

  def perform
    logger.info 'Clearing Rails cache'
    Rails.cache.clear
    logger.info 'Clearing Rails cache completed'
  end
end
