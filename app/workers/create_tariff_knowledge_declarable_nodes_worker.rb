class CreateTariffKnowledgeDeclarableNodesWorker
  include Sidekiq::Worker

  sidekiq_options queue: :sync, retry: false

  def perform
    TariffKnowledge::DeclarableNodeLoader.call
  end
end
