module AiUsage
  LOG_FIELDS = %i[provider model event_kind input_tokens cached_input_tokens output_tokens total_tokens input_cost_usd cached_input_cost_usd output_cost_usd total_cost_usd pricing_known].freeze
  Metadata = Data.define(*LOG_FIELDS)

module_function

  def metadata_for(model:, event_kind:, usage:)
    usage = normalize_usage(usage)
    pricing = pricing_for(model)
    input_price, cached_input_price, output_price = %w[input_per_million_tokens cached_input_per_million_tokens output_per_million_tokens].map { |key| price_for(pricing, key) }
    input_tokens, cached_input_tokens, output_tokens = usage.values_at(:input_tokens, :cached_input_tokens, :output_tokens)
    uncached_input_tokens = input_tokens && input_tokens - cached_input_tokens.to_i
    uncached_input_cost = cost_for(uncached_input_tokens, input_price)
    cached_input_cost = cost_for(cached_input_tokens, cached_input_price)
    input_cost = sum_cost(uncached_input_cost, cached_input_cost)
    output_cost = cost_for(output_tokens, output_price)

    Metadata.new(
      provider: 'openai',
      model:,
      event_kind:,
      input_tokens:,
      cached_input_tokens:,
      output_tokens:,
      total_tokens: usage[:total_tokens] || [input_tokens, output_tokens].compact.sum,
      input_cost_usd: input_cost,
      cached_input_cost_usd: cached_input_cost,
      output_cost_usd: output_cost,
      total_cost_usd: [input_cost, output_cost].compact.then { |costs| costs.sum if costs.any? },
      pricing_known: pricing_known?(pricing, input_tokens: uncached_input_tokens, cached_input_tokens:, output_tokens:, input_price:, cached_input_price:, output_price:),
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
      output_tokens: [left.output_tokens, right.output_tokens].compact.sum,
      total_tokens: [left.total_tokens, right.total_tokens].compact.sum,
      input_cost_usd: sum_cost(left.input_cost_usd, right.input_cost_usd),
      cached_input_cost_usd: sum_cost(left.cached_input_cost_usd, right.cached_input_cost_usd),
      output_cost_usd: sum_cost(left.output_cost_usd, right.output_cost_usd),
      total_cost_usd: sum_cost(left.total_cost_usd, right.total_cost_usd),
      pricing_known: left.pricing_known && right.pricing_known,
    )
  end

  def normalize_usage(usage)
    usage = usage.respond_to?(:to_h) ? usage.to_h : {}
    prompt_details = usage['prompt_tokens_details'] || usage[:prompt_tokens_details] || {}
    {
      input_tokens: integer_value(usage['prompt_tokens'] || usage[:prompt_tokens] || usage['input_tokens'] || usage[:input_tokens]),
      cached_input_tokens: integer_value(prompt_details['cached_tokens'] || prompt_details[:cached_tokens]),
      output_tokens: integer_value(usage['completion_tokens'] || usage[:completion_tokens] || usage['output_tokens'] || usage[:output_tokens]),
      total_tokens: integer_value(usage['total_tokens'] || usage[:total_tokens]),
    }
  end

  def pricing_for(model)
    pricing = TradeTariffBackend.openai_model_pricing
    pricing.is_a?(Hash) ? pricing.fetch(model.to_s, {}) : {}
  end

  def price_for(pricing, key)
    Float(pricing[key], exception: false) if pricing.is_a?(Hash)
  end

  def cost_for(tokens, per_million_tokens)
    tokens * per_million_tokens / 1_000_000.0 if tokens && per_million_tokens
  end

  def pricing_known?(pricing, input_tokens:, cached_input_tokens:, output_tokens:, input_price:, cached_input_price:, output_price:)
    !!(pricing.present? && pricing.is_a?(Hash) &&
      (input_tokens.to_i <= 0 || input_price) &&
      (cached_input_tokens.to_i <= 0 || cached_input_price) &&
      (output_tokens.to_i <= 0 || output_price))
  end

  def sum_cost(left, right) = [left, right].compact.then { |costs| costs.sum if costs.any? }

  def integer_value(value)
    Integer(value, exception: false) unless value.nil?
  end
end
