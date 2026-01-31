require_relative '../lib/label_generator/instrumentation'
require_relative '../lib/label_generator/logger'

class LabelService
  def initialize(batch, page_number: nil)
    @batch = LabelBatchPresenter.new(batch)
    @page_number = page_number
  end

  def call
    model = configured_model
    result = nil

    LabelGenerator::Instrumentation.api_call(batch_size: batch.size, model:, page_number:) do
      result = TradeTariffBackend.ai_client.call(context_for(batch), model: model)
      result
    end

    @last_ai_response = result
    result = AiResponseSanitizer.call(result)
    data = Array.wrap(result.fetch('data', []))

    data.filter_map do |item|
      goods_nomenclature = batch.goods_nomenclature_for(item['commodity_code'])

      if goods_nomenclature.nil?
        LabelGenerator::Instrumentation.label_not_found(
          commodity_code: item['commodity_code'],
          page_number:,
        )
        next
      end

      GoodsNomenclatureLabel.build(goods_nomenclature, item)
    end
  end

  attr_reader :last_ai_response

  private

  attr_reader :batch, :page_number

  def configured_model
    config = AdminConfiguration.classification.by_name('label_model')
    return TradeTariffBackend.ai_model if config.nil?

    config.value.is_a?(Hash) ? config.value['selected'] : TradeTariffBackend.ai_model
  end

  def configured_context
    config = AdminConfiguration.classification.by_name('label_context')
    config&.value.presence || I18n.t('contexts.label_commodity.instructions')
  end

  def context_for(batch)
    "#{configured_context}\n\n#{batch.to_json}"
  end

  class << self
    def call(batch, page_number: nil)
      new(batch, page_number:).call
    end
  end
end
