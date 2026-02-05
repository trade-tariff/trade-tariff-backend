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
    result = ExtractBottomJson.call(result) unless result.is_a?(Hash) || result.is_a?(Array)

    data = extract_data(result)

    # Filter to only Hash items - AI sometimes returns malformed data
    data = data.select { |item| item.is_a?(Hash) }

    if data.empty? && result.present?
      Rails.logger.warn("LabelService: AI returned no valid items. Response sample: #{result.to_s[0..200]}")
    end

    data.filter_map do |item|
      commodity_code = item['commodity_code'] || item['goods_nomenclature_item_id']
      goods_nomenclature = batch.goods_nomenclature_for(commodity_code)

      if goods_nomenclature.nil?
        LabelGenerator::Instrumentation.label_not_found(
          commodity_code:,
          page_number:,
        )
        next
      end

      contextual_description = batch.contextual_description_for(goods_nomenclature)
      GoodsNomenclatureLabel.build(goods_nomenclature, item, contextual_description:)
    end
  end

  attr_reader :last_ai_response

  private

  attr_reader :batch, :page_number

  def configured_model
    config = AdminConfiguration.classification.by_name('label_model')
    config&.selected_option(default: TradeTariffBackend.ai_model) || TradeTariffBackend.ai_model
  end

  def configured_context
    config = AdminConfiguration.classification.by_name('label_context')
    config&.value.to_s
  end

  def context_for(batch)
    "#{configured_context}\n\n#{batch.to_json}"
  end

  def extract_data(result)
    if result.blank?
      Rails.logger.error("LabelService: AI returned unexpected response type: #{result.class}")
      return []
    end

    case result
    when Hash
      Array.wrap(result['data'])
    when Array
      result
    end
  end

  class << self
    def call(batch, page_number: nil)
      new(batch, page_number:).call
    end
  end
end
