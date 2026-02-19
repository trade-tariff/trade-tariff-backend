# Processes goods nomenclature changes for a single chapter after a
# CDS/TARIC import cycle. Enqueued by GoodsNomenclatureChangeAccumulator.
#
# Three responsibilities:
# 1. Mark affected self-texts stale and clear their search embeddings so
#    stale content is excluded from vector search until regenerated.
# 2. Re-run MechanicalBuilder for the chapter to regenerate self-texts
#    with updated ancestor chains and descriptions.
# 3. Destroy labels for SIDs whose descriptions changed, so the labelling
#    pipeline regenerates them with the new description text.
class GoodsNomenclatureChangeWorker
  include Sidekiq::Worker

  sidekiq_options queue: :default, retry: 2

  def perform(chapter_code, sid_change_map)
    affected_sids = sid_change_map.keys.map(&:to_i)

    mark_self_texts_stale(affected_sids)
    regenerate_mechanical_self_texts(chapter_code)
    invalidate_labels(sid_change_map)
  end

  private

  def mark_self_texts_stale(sids)
    GoodsNomenclatureSelfText
      .where(goods_nomenclature_sid: sids)
      .where(stale: false)
      .update(stale: true, search_embedding: nil, updated_at: Time.zone.now)
  end

  def regenerate_mechanical_self_texts(chapter_code)
    chapter = TimeMachine.now do
      Chapter.actual
        .where(Sequel.like(:goods_nomenclature_item_id, "#{chapter_code}%"))
        .eager(:goods_nomenclature_descriptions)
        .first
    end
    return unless chapter

    GenerateSelfText::MechanicalBuilder.call(chapter)
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
  end
end
