require_relative '../lib/label_generator/instrumentation'
require_relative '../lib/label_generator/logger'

class LabelService
  def initialize(batch, page_number: nil)
    @batch = LabelBatchPresenter.new(batch)
    @page_number = page_number
  end

  def call
    model = TradeTariffBackend.ai_model
    result = nil

    LabelGenerator::Instrumentation.api_call(batch_size: batch.size, model:, page_number:) do
      result = TradeTariffBackend.ai_client.call(context_for(batch))
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

  def context_for(batch)
    "#{I18n.t('contexts.label_commodity.instructions')}\n\n#{batch.to_json}"
  end

  class << self
    def call(batch, page_number: nil)
      new(batch, page_number:).call
    end
  end
end
