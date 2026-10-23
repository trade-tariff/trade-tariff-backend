class RefreshTariffKnowledgeCompressedNotesWorker
  include Sidekiq::Worker

  sidekiq_options queue: :sync, retry: false

  def perform
    result = TariffKnowledge::CompressedNoteRefresh.call
    if result.skipped
      logger.info('CompressedNoteRefresh skipped: fingerprint unchanged since last run')
    else
      logger.info("CompressedNoteRefresh complete: #{result.goods_nomenclature_count} notes, #{result.expired_note_count} expired")
    end
  end
end
