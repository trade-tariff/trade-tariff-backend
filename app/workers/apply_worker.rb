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
  end
end
