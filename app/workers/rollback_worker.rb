class RollbackWorker
  include Sidekiq::Worker

  sidekiq_options queue: :rollbacks, retry: false

  def perform(date, redownload = false)
    if TradeTariffBackend.uk?
      CdsSynchronizer.rollback(date, keep: redownload)
    else
      TaricSynchronizer.rollback(date, keep: redownload)
    end

    ViewService.refresh_materialized_views!
  end
end
