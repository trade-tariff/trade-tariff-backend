class ApplyWorker
  include Sidekiq::Worker

  sidekiq_options queue: :rollbacks, retry: false

  def perform
    if TradeTariffBackend.use_cds?
      TariffSynchronizer.apply_cds
    else
      TariffSynchronizer.apply
    end

    GoodsNomenclatures::TreeNode.refresh!
  end
end
