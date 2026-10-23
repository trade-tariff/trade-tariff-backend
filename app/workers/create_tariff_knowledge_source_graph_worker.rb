class CreateTariffKnowledgeSourceGraphWorker
  include Sidekiq::Worker

  sidekiq_options queue: :within_1_hour, retry: false

  def perform
    TariffKnowledge::SourceGraphLoader.call
  end
end
