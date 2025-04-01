class ApplyWorker
  include Sidekiq::Worker

  sidekiq_options queue: :rollbacks, retry: false

  def perform
    if TradeTariffBackend.uk?
      CdsSynchronizer.apply
    else
      TaricSynchronizer.apply
    end

    GoodsNomenclatures::TreeNode.refresh!

    # Clear frontend cache
    Rails.logger.info 'Clearing frontend cache'
    TradeTariffBackend.frontend_redis.flushdb
    Rails.logger.info 'Frontend cache cleared'

    # Queue a Sidekiq job to clear all caches
    ClearCacheWorker.perform_async
  end
end
