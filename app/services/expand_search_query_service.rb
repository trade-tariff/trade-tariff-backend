class ExpandSearchQueryService
  NUMERIC_CODE_PATTERN = /\A\d+\z/
  CACHE_TTL = 7.days
  EXPANSION_TIMEOUT_SECONDS = 5.0
  EXPANSION_TIMEOUT_MS = (EXPANSION_TIMEOUT_SECONDS * 1000).to_i

  Result = Data.define(:expanded_query, :reason)

  def initialize(query, request_id: nil)
    @query = query.to_s.strip
    @request_id = request_id
  end

  def call
    return unchanged_result if query.blank?
    return unchanged_result if numeric_code?

    expand_query
  end

  class << self
    def call(query, request_id: nil)
      new(query, request_id:).call
    end

    def clear_cache!
      Rails.cache.delete_matched('expand_search_query/*')
    end

    def valid_response?(response)
      response.is_a?(Hash) && response['expanded_query'].is_a?(String) &&
        response['expanded_query'].present? && response['error'].blank?
    end
  end

private

  attr_reader :query, :request_id

  def numeric_code?
    NUMERIC_CODE_PATTERN.match?(query)
  end

  def expand_query
    cached = Rails.cache.read(cache_key)
    if cached
      cached_response = cached.is_a?(Hash) ? cached.stringify_keys : cached
      if self.class.valid_response?(cached_response)
        return Result.new(expanded_query: cached_response['expanded_query'], reason: cached_response['reason'])
      end

      record_failure('Cached query expansion was malformed')
      Rails.cache.delete(cache_key)
    end

    response = Search::Instrumentation.api_call(
      request_id:,
      model: configured_model,
      attempt_number: 1,
      operation: 'search_query_expansion',
    ) do
      OpenaiClient.call(
        context_for(query),
        model: configured_model,
        reasoning_effort: configured_reasoning_effort,
        event_kind: 'search_query_expansion',
        timeout: EXPANSION_TIMEOUT_SECONDS,
      )
    end

    if self.class.valid_response?(response)
      result_hash = { expanded_query: response['expanded_query'], reason: response['reason'] }
      Rails.cache.write(cache_key, result_hash, expires_in: CACHE_TTL)
      Result.new(**result_hash)
    else
      record_failure('Query expansion response was malformed')
      unchanged_result
    end
  rescue OpenaiClient::DeadlineExceeded => e
    TradeTariffRequest.record_search_failure(Search::FailureCodes::QUERY_EXPANSION_FAILED)
    Search::Instrumentation.query_expansion_timed_out(
      request_id:,
      timeout_ms: EXPANSION_TIMEOUT_MS,
      elapsed_ms: (e.elapsed_seconds * 1000).round(2),
      model: configured_model,
      fallback_outcome: 'original_query',
    )
    unchanged_result
  rescue StandardError => e
    record_failure(e.message, error_type: e.class.name)
    unchanged_result
  end

  def record_failure(message, error_type: 'InvalidResponse')
    Search::Instrumentation.search_stage_failed(
      request_id:,
      search_type: 'interactive',
      failure_code: Search::FailureCodes::QUERY_EXPANSION_FAILED,
      operation: 'search_query_expansion',
      error_type:,
      error_message: message,
    )
  end

  def cache_key
    @cache_key ||= "expand_search_query/#{configured_model}/#{context_digest}/#{query.downcase}"
  end

  def context_digest
    Digest::MD5.hexdigest(configured_context)[0, 8]
  end

  def model_config
    @model_config ||= AdminConfiguration.nested_options_value('expand_model')
  end

  def configured_model
    model_config[:selected]
  end

  def configured_reasoning_effort
    model_config[:sub_values]['reasoning_effort']
  end

  def configured_context
    config = AdminConfiguration.classification.by_name('expand_query_context')
    config&.value.to_s
  end

  def context_for(search_query)
    configured_context.gsub('%{search_query}', search_query)
  end

  def unchanged_result
    Result.new(expanded_query: query, reason: nil)
  end
end
