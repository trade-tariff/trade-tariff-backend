class AiUsage::PricingCalculator
  def self.call(...) = new(...).call

  def initialize(model:, event_kind:, usage:)
    @model = model
    @event_kind = event_kind
    @usage = normalize_usage(usage)
    all_pricing = TradeTariffBackend.openai_model_pricing
    @pricing = all_pricing.is_a?(Hash) ? all_pricing.fetch(model.to_s, {}) : {}
  end

  def call
    assign_tokens
    assign_prices
    assign_costs

    {
      provider: 'openai',
      model: @model,
      event_kind: @event_kind,
      input_tokens: @input_tokens,
      cached_input_tokens: @cached_input_tokens,
      cache_write_input_tokens: @cache_write_input_tokens,
      output_tokens: @output_tokens,
      total_tokens: @usage[:total_tokens] || [@input_tokens, @output_tokens].compact.sum,
      input_cost_usd: @input_cost,
      cached_input_cost_usd: @cached_input_cost,
      cache_write_input_cost_usd: @cache_write_input_cost,
      output_cost_usd: @output_cost,
      total_cost_usd: sum_cost(@input_cost, @output_cost),
      pricing_known: pricing_known?,
    }
  end

private

  def assign_tokens
    @input_tokens, @cached_input_tokens, @cache_write_input_tokens, @output_tokens =
      @usage.values_at(:input_tokens, :cached_input_tokens, :cache_write_input_tokens, :output_tokens)
    @uncached_input_tokens = @input_tokens && [@input_tokens - @cached_input_tokens.to_i - @cache_write_input_tokens.to_i, 0].max
  end

  def assign_prices
    @input_price, @cached_input_price, @output_price =
      %w[input_per_million_tokens cached_input_per_million_tokens output_per_million_tokens].map { |key| number_for(key) }
    @long_context = long_context?
    @input_multiplier = @long_context ? positive_number_for('long_context_input_multiplier') : 1.0
    @output_multiplier = @long_context ? positive_number_for('long_context_output_multiplier') : 1.0
    @input_price *= @input_multiplier if @input_price && @input_multiplier
    @cached_input_price *= @input_multiplier if @cached_input_price && @input_multiplier
    cache_write_multiplier = positive_number_for('cache_write_input_multiplier')
    @cache_write_input_price = @input_price * cache_write_multiplier if @input_price && cache_write_multiplier
    @output_price *= @output_multiplier if @output_price && @output_multiplier
  end

  def assign_costs
    uncached_input_cost = cost_for(@uncached_input_tokens, @input_price)
    @cached_input_cost = cost_for(@cached_input_tokens, @cached_input_price)
    @cache_write_input_cost = cost_for(@cache_write_input_tokens, @cache_write_input_price)
    @input_cost = [uncached_input_cost, @cached_input_cost, @cache_write_input_cost].compact.then { |costs| costs.sum if costs.any? }
    @output_cost = cost_for(@output_tokens, @output_price)
  end

  def normalize_usage(usage)
    usage = usage.respond_to?(:to_h) ? usage.to_h : {}
    prompt_details = usage['prompt_tokens_details'] || usage[:prompt_tokens_details] || {}
    {
      input_tokens: integer_value(usage['prompt_tokens'] || usage[:prompt_tokens] || usage['input_tokens'] || usage[:input_tokens]),
      cached_input_tokens: integer_value(prompt_details['cached_tokens'] || prompt_details[:cached_tokens]),
      cache_write_input_tokens: integer_value(prompt_details['cache_write_tokens'] || prompt_details[:cache_write_tokens]),
      output_tokens: integer_value(usage['completion_tokens'] || usage[:completion_tokens] || usage['output_tokens'] || usage[:output_tokens]),
      total_tokens: integer_value(usage['total_tokens'] || usage[:total_tokens]),
    }
  end

  def long_context?
    threshold = positive_number_for('long_context_input_token_threshold')
    threshold && @input_tokens.to_i > threshold
  end

  def pricing_known?
    !!(@pricing.present? &&
      (@uncached_input_tokens.to_i <= 0 || @input_price) &&
      (@cached_input_tokens.to_i <= 0 || @cached_input_price) &&
      (@cache_write_input_tokens.to_i <= 0 || @cache_write_input_price) &&
      (@output_tokens.to_i <= 0 || @output_price) &&
      (!@long_context || (@input_multiplier && @output_multiplier)))
  end

  def positive_number_for(key)
    value = number_for(key)
    value if value&.positive?
  end

  def number_for(key) = Float(@pricing[key], exception: false)

  def cost_for(tokens, price)
    tokens * price / 1_000_000.0 if tokens && price
  end

  def sum_cost(left, right) = [left, right].compact.then { |costs| costs.sum if costs.any? }

  def integer_value(value)
    Integer(value, exception: false) unless value.nil?
  end
end
