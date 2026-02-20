# Detects goods nomenclature changes and triggers downstream regeneration
# of self-texts, search embeddings, and labels.
#
# Two queries cover all cases:
#
# 1. "Going live today" - records whose validity_start_date is today
# 2. "Inserted today" - current records from files applied in today's
#    import run. On UK, matched by filename from the tariff_updates table.
#    On XI, matched by operation_date (the file's issue_date, indexed).
#
# Structure/indent changes regenerate self-texts for the affected chapter.
# Description changes additionally invalidate labels for relabelling.
class GoodsNomenclatureReconciliationWorker
  include Sidekiq::Worker

  sidekiq_options queue: :default, retry: 2

  def perform
    affected = detect_changes
    return if affected.empty?

    chapters = affected.group_by { |_sid, _type, item_id| item_id[0, 2] }

    chapters.each do |chapter_code, entries|
      sids = entries.map(&:first).uniq
      mark_self_texts_stale(sids)
      regenerate_self_texts(chapter_code)
    end

    description_sids = affected
      .select { |_sid, type, _item_id| type == :description_changed }
      .map(&:first)
      .uniq

    structure_only_sids = affected.map(&:first).uniq - description_sids
    GoodsNomenclatureSelfText.regenerate_search_embeddings(structure_only_sids)

    invalidate_labels(description_sids)
  end

  private

  def detect_changes
    (detect_going_live + detect_inserted_today).uniq { |sid, type, _| [sid, type] }
  end

  def detect_going_live
    today = Date.current

    gn_sids = GoodsNomenclature
      .where(validity_start_date: today)
      .select_map(%i[goods_nomenclature_sid goods_nomenclature_item_id])
      .map { |sid, item_id| [sid, :structure_changed, item_id] }

    indent_sids = GoodsNomenclatureIndent
      .where(validity_start_date: today)
      .select_map(%i[goods_nomenclature_sid goods_nomenclature_item_id])
      .map { |sid, item_id| [sid, :structure_changed, item_id] }

    desc_sids = GoodsNomenclatureDescriptionPeriod
      .where(validity_start_date: today)
      .select_map(%i[goods_nomenclature_sid goods_nomenclature_item_id])
      .map { |sid, item_id| [sid, :description_changed, item_id] }

    gn_sids + indent_sids + desc_sids
  end

  def detect_inserted_today
    filter = todays_import_filter
    return [] if filter.nil?

    gn_sids = TimeMachine.now do
      GoodsNomenclature
        .actual
        .where(filter)
        .select_map(%i[goods_nomenclature_sid goods_nomenclature_item_id])
        .map { |sid, item_id| [sid, :structure_changed, item_id] }
    end

    indent_sids = TimeMachine.now do
      GoodsNomenclatureIndent
        .actual
        .where(filter)
        .select_map(%i[goods_nomenclature_sid goods_nomenclature_item_id])
        .map { |sid, item_id| [sid, :structure_changed, item_id] }
    end

    desc_sids = TimeMachine.now do
      GoodsNomenclatureDescriptionPeriod
        .actual
        .where(filter)
        .select_map(%i[goods_nomenclature_sid goods_nomenclature_item_id])
        .map { |sid, item_id| [sid, :description_changed, item_id] }
    end

    gn_sids + indent_sids + desc_sids
  end

  def todays_import_filter
    applied_today = TariffSynchronizer::BaseUpdate
      .where(state: TariffSynchronizer::BaseUpdate::APPLIED_STATE)
      .where(Sequel.lit('applied_at::date = ?', Date.current))

    if TradeTariffBackend.uk?
      filenames = applied_today.select_map(:filename)
      filenames.any? ? { filename: filenames } : nil
    else
      issue_dates = applied_today.select_map(:issue_date)
      issue_dates.any? ? { Sequel[:operation_date] => issue_dates } : nil
    end
  end

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

  def invalidate_labels(sids)
    return if sids.empty?

    TimeMachine.now do
      GoodsNomenclatureLabel
        .where(goods_nomenclature_sid: sids)
        .actual
        .each(&:destroy)
    end

    RelabelGoodsNomenclatureWorker.perform_async
  end
end
