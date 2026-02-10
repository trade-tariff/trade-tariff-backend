class ApplyWorker
  include Sidekiq::Worker

  sidekiq_options queue: :sync, retry: false

  def perform
    TradeTariffBackend.uk? ? CdsSynchronizer.apply : TaricSynchronizer.apply

    MaterializeViewHelper.refresh_materialized_view

    PopulateTariffChangesWorker.perform_async
    ClearCacheWorker.perform_async
  end
end
