class CreateTariffKnowledgeDeclarableNodesWorker
  include Sidekiq::Worker

  sidekiq_options queue: :within_1_hour, retry: false

  def perform
    TariffKnowledge::DeclarableNodeLoader.call
  end
end
