module AiUsage
  # Field names merged into the 'api_call_completed.search' notification
  # payload by Search::Instrumentation::ApiEvents#api_call
  # (app/lib/search/instrumentation/api_events.rb) — also depended on by
  # Api::Admin::Search::Evaluation::SearchesController#create's usage
  # subscriber. Renaming a field here needs a check in both places.
  LOG_FIELDS = %i[
    provider
    model
    event_kind
    input_tokens
    cached_input_tokens
    cache_write_input_tokens
    output_tokens
    reasoning_tokens
    total_tokens
    input_cost_usd
    cached_input_cost_usd
    cache_write_input_cost_usd
    output_cost_usd
    total_cost_usd
    pricing_known
    finish_reason
    served_model
    service_tier
    reasoning_effort
    openai_request_id
    openai_response_id
  ].freeze
  OPTIONAL_FIELDS = {
    cache_write_input_tokens: nil,
    cache_write_input_cost_usd: nil,
    reasoning_tokens: nil,
    finish_reason: nil,
    served_model: nil,
    service_tier: nil,
    reasoning_effort: nil,
    openai_request_id: nil,
    openai_response_id: nil,
  }.freeze
  RESPONSE_FIELDS = %i[finish_reason served_model service_tier reasoning_effort openai_request_id openai_response_id].freeze
  Metadata = Data.define(*LOG_FIELDS) do
    def initialize(**attributes)
      super(**OPTIONAL_FIELDS.merge(attributes))
    end
  end

module_function

  def metadata_for(model:, event_kind:, usage:, **response_fields)
    Metadata.new(
      **PricingCalculator.call(model:, event_kind:, usage:),
      **response_fields.slice(*RESPONSE_FIELDS),
    )
  end

  def attach_metadata(result, metadata)
    return result unless metadata && (result.is_a?(Array) || result.is_a?(Hash) || result.is_a?(String))

    result.define_singleton_method(:ai_usage) { metadata }
    result
  rescue TypeError
    result
  end

  def metadata_from(object)
    object.ai_usage if object.respond_to?(:ai_usage)
  end

  def payload_from(object) = metadata_from(object)&.to_h&.compact || {}

  def payload_from_error(error) = error.respond_to?(:ai_usage) && error.ai_usage ? error.ai_usage.to_h.compact : {}

  def safe_error_message(error)
    return "OpenAI API error status=#{error.status}" if error.is_a?(OpenaiClient::ApiError)

    error.message.to_s.truncate(500)
  end

  def add_log_fields!(data, event)
    LOG_FIELDS.each { |key| data[key] = event.payload[key] if event.payload.key?(key) }
    data
  end

  def merge_metadata(left, right)
    left = metadata_from(left) || left
    right = metadata_from(right) || right
    return left unless right
    return right unless left

    Metadata.new(
      provider: left.provider,
      model: left.model,
      event_kind: left.event_kind || right.event_kind,
      input_tokens: [left.input_tokens, right.input_tokens].compact.sum,
      cached_input_tokens: [left.cached_input_tokens, right.cached_input_tokens].compact.sum,
      cache_write_input_tokens: [left.cache_write_input_tokens, right.cache_write_input_tokens].compact.sum,
      output_tokens: [left.output_tokens, right.output_tokens].compact.sum,
      reasoning_tokens: sum_optional(left.reasoning_tokens, right.reasoning_tokens),
      total_tokens: [left.total_tokens, right.total_tokens].compact.sum,
      input_cost_usd: sum_cost(left.input_cost_usd, right.input_cost_usd),
      cached_input_cost_usd: sum_cost(left.cached_input_cost_usd, right.cached_input_cost_usd),
      cache_write_input_cost_usd: sum_cost(left.cache_write_input_cost_usd, right.cache_write_input_cost_usd),
      output_cost_usd: sum_cost(left.output_cost_usd, right.output_cost_usd),
      total_cost_usd: sum_cost(left.total_cost_usd, right.total_cost_usd),
      pricing_known: left.pricing_known && right.pricing_known,
      finish_reason: right.finish_reason || left.finish_reason,
      served_model: right.served_model || left.served_model,
      service_tier: right.service_tier || left.service_tier,
      reasoning_effort: right.reasoning_effort || left.reasoning_effort,
      openai_request_id: right.openai_request_id || left.openai_request_id,
      openai_response_id: right.openai_response_id || left.openai_response_id,
    )
  end

  def sum_cost(left, right) = [left, right].compact.then { |costs| costs.sum if costs.any? }

  def sum_optional(left, right) = [left, right].compact.then { |values| values.sum if values.any? }
end
