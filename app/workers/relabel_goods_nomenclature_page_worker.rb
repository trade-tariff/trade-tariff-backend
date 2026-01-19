class RelabelGoodsNomenclaturePageWorker
  include Sidekiq::Worker

  sidekiq_options queue: :sync, retry: 3

  PAGE_SIZE = TradeTariffBackend.goods_nomenclature_label_page_size

  def perform(page_number)
    batch = GoodsNomenclatureLabel.goods_nomenclatures_dataset.paginate(page_number, PAGE_SIZE).all

    return if batch.empty?

    labels = LabelService.call(batch)

    labels.each(&:save)

    Rails.logger.info "Relabelled page #{page_number} with #{labels.size} labels"
  end
end
