# Processes goods nomenclature changes for a single chapter after a
# CDS/TARIC import cycle. Enqueued by GoodsNomenclatureChangeAccumulator.
#
# Four responsibilities:
# 1. Mark affected self-texts stale and clear their search embeddings so
#    stale content is excluded from vector search until regenerated.
# 2. Re-run MechanicalBuilder and AiBuilder for the chapter to regenerate
#    self-texts with updated ancestor chains and descriptions.
# 3. Destroy labels for SIDs whose descriptions changed, so the labelling
#    pipeline regenerates them with the new description text.
# 4. Enqueue RelabelGoodsNomenclatureWorker to recreate destroyed labels.
class GoodsNomenclatureChangeWorker
  include Sidekiq::Worker

  sidekiq_options queue: :default, retry: 2

  def perform(chapter_code, sid_change_map)
    affected_sids = sid_change_map.keys.map(&:to_i)

    mark_self_texts_stale(affected_sids)
    regenerate_self_texts(chapter_code)
    invalidate_labels(sid_change_map)
  end

  private

  def mark_self_texts_stale(sids)
    GoodsNomenclatureSelfText
      .where(goods_nomenclature_sid: sids)
      .where(stale: false)
      .update(stale: true, search_embedding: nil, updated_at: Time.zone.now)
  end

  def regenerate_self_texts(chapter_code)
    chapter = TimeMachine.now { Chapter.actual.by_code(chapter_code).first }
    return unless chapter

    GenerateSelfText::MechanicalBuilder.call(chapter)
    GenerateSelfText::AiBuilder.call(chapter)
  end

  def invalidate_labels(sid_change_map)
    sids_with_description_changes = sid_change_map.select { |_sid, change_types|
      change_types.include?('description_changed')
    }.keys.map(&:to_i)

    return if sids_with_description_changes.empty?

    TimeMachine.now do
      GoodsNomenclatureLabel
        .where(goods_nomenclature_sid: sids_with_description_changes)
        .actual
        .each(&:destroy)
    end

    RelabelGoodsNomenclatureWorker.perform_async
  end
end
