require_relative '../lib/label_generator/instrumentation'
require_relative '../lib/label_generator/logger'

class RelabelGoodsNomenclaturePageWorker
  include Sidekiq::Worker

  EAGER = [
    {
      ancestors: [
        :goods_nomenclature_descriptions,
      ],
    },
    :goods_nomenclature_descriptions,
  ].freeze

  sidekiq_options queue: :within_1_day, retry: 3, slack_alerts: false

  def perform(sids, batch_index = 1)
    @label_service = nil

    page_number = batch_index

    TimeMachine.now do
      batch = GoodsNomenclature.actual
                .with_leaf_column
                .declarable
                .where(Sequel[:goods_nomenclatures][:goods_nomenclature_sid] => sids)
                .eager(EAGER)
                .all

      return if batch.empty?

      LabelGenerator::Instrumentation.page_started(page_number:, batch_size: batch.size)

      LabelGenerator::Instrumentation.page_completed(page_number:) do |payload|
        @label_service = LabelService.new(batch, page_number:)
        labels = @label_service.call

        labels.each do |label|
          if save_label(label, page_number:)
            payload[:labels_created] += 1
          else
            payload[:labels_failed] += 1
          end
        end
      end

      batch_sids = batch.map(&:goods_nomenclature_sid)
      ScoreLabelBatchWorker.perform_async(batch_sids)
    end
  rescue StandardError => e
    LabelGenerator::Instrumentation.page_failed(
      page_number:,
      error: e,
      ai_response: @label_service&.last_ai_response,
    )
    raise
  end

  private

  def save_label(label, page_number:)
    unless label.valid?
      error = Sequel::ValidationFailed.new(label)
      LabelGenerator::Instrumentation.label_save_failed(label, error, page_number:)
      return false
    end

    upsert_label(label)
    LabelGenerator::Instrumentation.label_saved(label, page_number:)
    true
  rescue Sequel::Error => e
    LabelGenerator::Instrumentation.label_save_failed(label, e, page_number:)
    false
  end

  def upsert_label(label)
    now = Time.zone.now
    result = GoodsNomenclatureLabel.dataset.insert_conflict(
      target: :goods_nomenclature_sid,
      update: {
        labels: label.labels,
        description: label.description,
        original_description: label.original_description,
        synonyms: label.synonyms,
        colloquial_terms: label.colloquial_terms,
        known_brands: label.known_brands,
        context_hash: label.context_hash,
        stale: false,
        updated_at: now,
      },
      update_where: { Sequel[:goods_nomenclature_labels][:manually_edited] => false },
    ).returning(:goods_nomenclature_sid).insert(
      goods_nomenclature_sid: label.goods_nomenclature_sid,
      goods_nomenclature_type: label.goods_nomenclature_type,
      goods_nomenclature_item_id: label.goods_nomenclature_item_id,
      producline_suffix: label.producline_suffix,
      labels: label.labels,
      description: label.description,
      original_description: label.original_description,
      synonyms: label.synonyms,
      colloquial_terms: label.colloquial_terms,
      known_brands: label.known_brands,
      context_hash: label.context_hash,
      stale: false,
      manually_edited: false,
      created_at: now,
      updated_at: now,
    )

    return false if result.empty?

    persisted_label = GoodsNomenclatureLabel[label.goods_nomenclature_sid]
    Sequel::Plugins::HasPaperTrail.record_current_version!(persisted_label, created_at: now)
  end
end
