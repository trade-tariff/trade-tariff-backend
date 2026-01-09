class ApplyWorker
  include Sidekiq::Worker

  sidekiq_options queue: :sync, retry: false

  def perform
    TradeTariffBackend.uk? ? CdsSynchronizer.apply : TaricSynchronizer.apply

    MaterializedViewHelper.refresh_materialized_view

    ClearCacheWorker.perform_async
  end
end
