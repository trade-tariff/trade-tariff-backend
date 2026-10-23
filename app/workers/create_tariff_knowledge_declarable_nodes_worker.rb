class CreateTariffKnowledgeDeclarableNodesWorker
  include Sidekiq::Worker

  sidekiq_options queue: :within_1_minute, retry: false

  def perform
    TariffKnowledge::DeclarableNodeLoader.call
  end
end
