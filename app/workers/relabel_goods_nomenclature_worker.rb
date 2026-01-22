require_relative '../lib/label_generator/instrumentation'
require_relative '../lib/label_generator/logger'

class RelabelGoodsNomenclatureWorker
  include Sidekiq::Worker

  sidekiq_options queue: :sync, retry: false

  PAGE_SIZE = TradeTariffBackend.goods_nomenclature_label_page_size

  def perform
    # Refresh materialized view to get accurate counts
    refresh_materialized_view!

    total_records = GoodsNomenclatureLabel.goods_nomenclatures_dataset.count
    total_pages = GoodsNomenclatureLabel.goods_nomenclature_label_total_pages

    LabelGenerator::Instrumentation.generation_started(
      total_pages:,
      page_size: PAGE_SIZE,
      total_records:,
    )

    LabelGenerator::Instrumentation.generation_completed(total_pages:) do
      total_pages.times do |page_index|
        page_number = page_index + 1
        RelabelGoodsNomenclaturePageWorker.perform_async(page_number)
      end
    end
  end

  private

  def refresh_materialized_view!
    return if Rails.env.test?

    GoodsNomenclatureLabel.refresh!(concurrently: false)
  rescue StandardError => e
    Rails.logger.warn "Failed to refresh materialized view: #{e.message}"
  end
end
