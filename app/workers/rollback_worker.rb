class RollbackWorker
  include Sidekiq::Worker

  sidekiq_options queue: :rollbacks, retry: false

  def perform(date, redownload = false)
    if TradeTariffBackend.use_cds?
      TariffSynchronizer.rollback_cds(date, keep: redownload)
    else
      TariffSynchronizer.rollback(date, keep: redownload)
    end

    GoodsNomenclatures::TreeNode.refresh!
  end
end
