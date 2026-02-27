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

  def perform(page_number)
    @label_service = nil

    TimeMachine.now do
      batch = GoodsNomenclatureLabel.goods_nomenclatures_dataset.paginate(page_number, configured_page_size).eager(EAGER).all

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

      sids = batch.map(&:goods_nomenclature_sid)
      GoodsNomenclatureSelfText.regenerate_search_embeddings(sids)
      LabelConfidenceScorer.new.score(sids)
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

  def configured_page_size
    config = AdminConfiguration.classification.by_name('label_page_size')
    (config&.value || TradeTariffBackend.goods_nomenclature_label_page_size).to_i
  end

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
    GoodsNomenclatureLabel.dataset.insert_conflict(
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
    ).insert(
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
  end
end
