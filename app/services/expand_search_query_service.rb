class ExpandSearchQueryService
  NUMERIC_CODE_PATTERN = /\A\d+\z/

  Result = Struct.new(:expanded_query, :reason, keyword_init: true)

  def initialize(query)
    @query = query.to_s.strip
  end

  def call
    return unchanged_result if query.blank?
    return unchanged_result if numeric_code?

    expand_query
  end

  class << self
    def call(query)
      new(query).call
    end
  end

  private

  attr_reader :query

  def numeric_code?
    NUMERIC_CODE_PATTERN.match?(query)
  end

  def expand_query
    response = OpenaiClient.call(context_for(query), model: configured_model)

    if response.is_a?(Hash) && response['expanded_query'].present?
      Result.new(
        expanded_query: response['expanded_query'],
        reason: response['reason'],
      )
    else
      unchanged_result
    end
  rescue StandardError => e
    Rails.logger.error("ExpandSearchQueryService error: #{e.message}")
    unchanged_result
  end

  def configured_model
    config = AdminConfiguration.classification.by_name('expand_model')
    return TradeTariffBackend.ai_model if config.nil?

    config.value.is_a?(Hash) ? config.value['selected'] : TradeTariffBackend.ai_model
  end

  def configured_context
    config = AdminConfiguration.classification.by_name('expand_query_context')
    config&.value.presence || I18n.t('contexts.expand_search_query.instructions')
  end

  def context_for(search_query)
    configured_context.gsub('%{search_query}', search_query)
  end

  def unchanged_result
    Result.new(expanded_query: query, reason: nil)
  end
end
