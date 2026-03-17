require_relative '../lib/label_generator/instrumentation'
require_relative '../lib/label_generator/logger'

class RelabelGoodsNomenclatureWorker
  include Sidekiq::Worker

  sidekiq_options queue: :sync, retry: false, slack_alerts: false

  def perform
    sids = TimeMachine.now do
      GoodsNomenclatureLabel.goods_nomenclatures_dataset
        .map(:goods_nomenclature_sid)
    end

    page_size = configured_page_size
    batches = sids.each_slice(page_size).to_a
    total_pages = batches.size

    LabelGenerator::Instrumentation.generation_started(
      total_pages:,
      page_size:,
      total_records: sids.size,
    )

    LabelGenerator::Instrumentation.generation_completed(total_pages:) do
      batches.each_with_index do |sid_batch, index|
        batch_index = index + 1
        RelabelGoodsNomenclaturePageWorker.perform_async(sid_batch, batch_index)
      end
    end
  end

  private

  def configured_page_size
    config = AdminConfiguration.classification.by_name('label_page_size')
    (config&.value || TradeTariffBackend.goods_nomenclature_label_page_size).to_i
  end
end
