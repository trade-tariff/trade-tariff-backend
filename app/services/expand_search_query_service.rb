class ExpandSearchQueryService
  NUMERIC_CODE_PATTERN = /\A\d+\z/
  FORMATTED_NUMBER_PATTERN = /\d+(?:[.\s]+\d+)*/
  TARIFF_CODE_REFERENCE_PATTERN = /\b(?:heading|subheading|(?:commodity|tariff|hs|cn)\s+code)\s*[:#]?\s*(#{FORMATTED_NUMBER_PATTERN})(?![.\s]*\d)\b/i
  MAX_ADDED_TERMS = 5
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
      return false unless response.is_a?(Hash) && response['error'].blank?

      (response['expanded_query'].is_a?(String) && response['expanded_query'].present?) ||
        response['added_terms'].is_a?(Array)
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
        # Rebuild cached responses too. Entries written before the append
        # contract may hold a rewrite that replaces the original query.
        return result_from_response(cached_response)
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
      result = result_from_response(response)
      Rails.cache.write(cache_key, { expanded_query: result.expanded_query, reason: result.reason }, expires_in: CACHE_TTL)
      result
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

  def result_from_response(response)
    added_terms = added_phrases(response)
    expanded_query = added_terms.empty? ? query : [query, *added_terms].join(' ')

    Result.new(expanded_query:, reason: response['reason'])
  end

  def added_phrases(response)
    phrases = if response['added_terms'].is_a?(Array)
                response['added_terms'].grep(String)
              else
                legacy_phrases(response['expanded_query'].to_s)
              end

    phrases
      .map { |phrase| phrase.to_s.squish }
      .compact_blank
      .reject { |phrase| phrase_already_in_query?(phrase) }
      .reject { |phrase| invents_commodity_code?(phrase) }
      .uniq(&:downcase)
      .first(MAX_ADDED_TERMS)
  end

  # A legacy response holds a single rewritten query. Treat it as added text.
  # Strip the original query when the rewrite keeps it as a prefix. Then split
  # the remainder into comma-separated phrases.
  def legacy_phrases(expanded_query)
    rewritten = expanded_query.to_s.strip
    return [] if rewritten.blank? || rewritten.downcase == query.downcase

    prefix_match = /\A#{Regexp.escape(query)}\s+/i.match(rewritten)
    added_text = prefix_match ? prefix_match.post_match : rewritten

    added_text.split(',')
  end

  def phrase_already_in_query?(phrase)
    phrase_words = words_in(phrase)

    phrase_words.empty? || (phrase_words - words_in(query)).empty?
  end

  def words_in(text)
    text.to_s.downcase.scan(/[[:word:]]+/)
  end

  def invents_commodity_code?(phrase)
    # A number alone may be a quantity, dimension or product identifier.
    # Only explicitly labelled tariff references are treated as added codes.
    supplied_numbers = query.scan(FORMATTED_NUMBER_PATTERN).map { |number| code_digits(number) }
    phrase.scan(TARIFF_CODE_REFERENCE_PATTERN).flatten.any? { |code| !supplied_numbers.include?(code_digits(code)) }
  end

  def code_digits(value)
    value.delete('^0-9')
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
    @cache_key ||= "expand_search_query/v2/#{configured_model}/#{context_digest}/#{query.downcase}"
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
