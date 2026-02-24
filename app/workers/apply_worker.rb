class ApplyWorker
  include Sidekiq::Worker

  sidekiq_options queue: :sync, retry: false

  def perform
    Thread.current[:tariff_sync_run_id] = SecureRandom.uuid

    TariffSynchronizer::Instrumentation.sync_run_started(triggered_by: self.class.name)
    TariffSynchronizer::Instrumentation.apply_started(pending_count: TariffSynchronizer::BaseUpdate.pending.count)

    TradeTariffBackend.uk? ? CdsSynchronizer.apply : TaricSynchronizer.apply

    MaterializeViewHelper.refresh_materialized_view

    PopulateTariffChangesWorker.perform_async
    ClearCacheWorker.perform_async
  ensure
    Thread.current[:tariff_sync_run_id] = nil
  end
end
