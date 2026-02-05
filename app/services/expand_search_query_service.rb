class ExpandSearchQueryService
  NUMERIC_CODE_PATTERN = /\A\d+\z/
  CACHE_TTL = 7.days

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

    def clear_cache!
      Rails.cache.delete_matched('expand_search_query/*')
    end
  end

  private

  attr_reader :query

  def numeric_code?
    NUMERIC_CODE_PATTERN.match?(query)
  end

  def expand_query
    cached = Rails.cache.read(cache_key)
    return Result.new(**cached.symbolize_keys) if cached

    response = OpenaiClient.call(context_for(query), model: configured_model)

    if response.is_a?(Hash) && response['expanded_query'].present?
      result_hash = { expanded_query: response['expanded_query'], reason: response['reason'] }
      Rails.cache.write(cache_key, result_hash, expires_in: CACHE_TTL)
      Result.new(**result_hash)
    else
      unchanged_result
    end
  rescue StandardError => e
    Search::Instrumentation.search_failed(
      request_id: nil,
      error_type: e.class.name,
      error_message: e.message,
      search_type: 'expand_query',
    )
    unchanged_result
  end

  def cache_key
    @cache_key ||= "expand_search_query/#{configured_model}/#{context_digest}/#{query.downcase}"
  end

  def context_digest
    Digest::MD5.hexdigest(configured_context)[0, 8]
  end

  def configured_model
    AdminConfiguration.option_value('expand_model')
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
