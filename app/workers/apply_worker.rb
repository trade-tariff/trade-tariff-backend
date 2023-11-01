class ApplyWorker
  include Sidekiq::Worker

  sidekiq_options queue: :rollbacks, retry: false

  def perform
    if TradeTariffBackend.use_cds?
      CdsSynchronizer.apply
    else
      TaricSynchronizer.apply
    end

    GoodsNomenclatures::TreeNode.refresh!
  end
end
