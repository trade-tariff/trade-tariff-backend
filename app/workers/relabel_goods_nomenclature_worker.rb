class RelabelGoodsNomenclatureWorker
  include Sidekiq::Worker

  sidekiq_options queue: :sync, retry: false

  PAGE_SIZE = TradeTariffBackend.goods_nomenclature_label_page_size

  def perform
    total_pages = goods_nomenclature_label_total_pages

    total_pages.times do |page_index|
      page_number = page_index + 1
      RelabelGoodsNomenclaturePageWorker.perform_async(page_number)
    end

    Rails.logger.info "Enqueued #{total_pages} relabelling jobs"
  end

  delegate :goods_nomenclature_label_total_pages, to: GoodsNomenclatureLabel
end
