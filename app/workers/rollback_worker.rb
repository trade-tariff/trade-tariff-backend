class RollbackWorker
  include Sidekiq::Worker

  sidekiq_options queue: :sync, retry: false

  def perform(date, redownload = false)
    Thread.current[:tariff_sync_run_id] = SecureRandom.uuid

    TariffSynchronizer::Instrumentation.sync_run_started(triggered_by: self.class.name)
    TariffSynchronizer::Instrumentation.rollback_started(rollback_date: date, keep: redownload)

    if TradeTariffBackend.uk?
      CdsSynchronizer.rollback(date, keep: redownload)
    else
      TaricSynchronizer.rollback(date, keep: redownload)
    end

    MaterializeViewHelper.refresh_materialized_view
  ensure
    Thread.current[:tariff_sync_run_id] = nil
  end
end
