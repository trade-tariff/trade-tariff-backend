class GenerateTariffKnowledgeCompressedNotesWorker
  include Sidekiq::Worker

  sidekiq_options queue: :sync, retry: false

  def perform(goods_nomenclature_sids)
    TariffKnowledge::CompressedNoteGenerator.call(goods_nomenclature_sids:)
  end
end
