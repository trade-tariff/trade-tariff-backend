class RefreshTariffKnowledgeCompressedNotesWorker
  include Sidekiq::Worker

  sidekiq_options queue: :sync, retry: false

  def perform
    TariffKnowledge::CompressedNoteRefresh.call
  end
end
