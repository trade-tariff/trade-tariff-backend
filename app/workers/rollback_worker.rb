class RollbackWorker
  include Sidekiq::Worker

  sidekiq_options queue: :sync, retry: false

  def perform(date, redownload = false)
    if TradeTariffBackend.uk?
      CdsSynchronizer.rollback(date, keep: redownload)
    else
      TaricSynchronizer.rollback(date, keep: redownload)
    end

    MaterializeViewHelper.refresh_materialized_view
  end
end
