class RollbackWorker
  include Sidekiq::Worker

  sidekiq_options queue: :rollbacks, retry: false

  def perform(date, redownload = false)
    if TradeTariffBackend.uk?
      require 'pry'
      binding.pry
      CdsSynchronizer.rollback(date, keep: redownload)
    else
      TaricSynchronizer.rollback(date, keep: redownload)
    end

    GoodsNomenclatures::TreeNode.refresh!
  end
end
