class CreateTariffKnowledgeSourceGraphWorker
  include Sidekiq::Worker

  sidekiq_options queue: :sync, retry: false

  def perform
    TariffKnowledge::SourceGraphLoader.call
  end
end
