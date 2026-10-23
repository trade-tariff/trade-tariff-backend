class CreateTariffKnowledgeSourceGraphWorker
  include Sidekiq::Worker

  sidekiq_options queue: :within_1_minute, retry: false

  def perform
    TariffKnowledge::SourceGraphLoader.call
  end
end
