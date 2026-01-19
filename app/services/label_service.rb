class LabelService
  def initialize(batch)
    @batch = LabelBatchPresenter.new(batch)
  end

  def call
    result = TradeTariffBackend.ai_client.call(context_for(batch))

    labels = Array.wrap(result.fetch('data', [])).map do |item|
      goods_nomenclature = batch.goods_nomenclature_for(item['goods_nomenclature_item_id'])

      GoodsNomenclatureLabel.build(goods_nomenclature, item)
    end

    log_result(labels)

    labels
  end

  private

  def context_for(batch)
    "#{I18n.t('contexts.label_commodity.instructions')}\n\n#{batch.to_json}"
  end

  def log_result(labels)
    if labels.size == batch.size
      Rails.logger.info "Successfully labelled #{labels.size} batch"
    else
      Rails.logger.info "Expected #{batch.size} but got #{labels.size} labels"
    end
  end

  attr_reader :batch

  class << self
    def call(batch)
      instrument do
        new(batch).call
      end
    end

    def instrument
      start_time = Time.zone.now
      yield
    ensure
      end_time = Time.zone.now
      duration = end_time - start_time
      Rails.logger.debug "LabelService call took #{duration.round(2)} seconds"
    end
  end
end
