class SelfTextRegenerator
  def self.call
    dataset = GoodsNomenclatureSelfText.where(stale: false, manually_edited: false)
    item_ids = dataset.select_map(:goods_nomenclature_sid)
    count = dataset.update(stale: true)
    PaperTrail::BulkVersioning.record_current_versions_for_item_ids!(model: GoodsNomenclatureSelfText, item_ids:) if count.positive?
    $stdout.puts "Marked #{count} self-texts as stale."

    GenerateSelfTextWorker.perform_async
    $stdout.puts 'Enqueued regeneration. Check Sidekiq for progress.'
  end
end
