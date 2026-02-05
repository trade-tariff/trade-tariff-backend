class OpenaiClient
  MAX_RETRIES = 3
  RETRY_DELAY = 2 # seconds
  RETRYABLE_ERRORS = [
    Faraday::TimeoutError,
    Faraday::ConnectionFailed,
    Net::ReadTimeout,
    Net::OpenTimeout,
  ].freeze

  def call(context, model: nil)
    messages = if context.is_a?(Array)
                 context
               else
                 [{ role: 'user', content: context.to_s }]
               end

    model ||= TradeTariffBackend.ai_model
    config = MODEL_CONFIGS[model] || {}

    body = {
      model: model,
      messages: messages,
      user: TradeTariffBackend.openai_user,
      response_format: { type: 'json_object' },
    }.merge(config).to_json

    response = with_retry { self.class.client.post('chat/completions', body) }

    if response.success?
      json = response.body.dig('choices', 0, 'message', 'content') || ''

      begin
        JSON.parse(json)
      rescue StandardError
        json
      end
    else
      Rails.logger.error "OpenAIClient error: #{response.body}"
      ''
    end
  end

  private

  def with_retry
    attempts = 0

    begin
      attempts += 1
      yield
    rescue *RETRYABLE_ERRORS => e
      if attempts < MAX_RETRIES
        delay = RETRY_DELAY * (2**(attempts - 1)) # exponential backoff: 2s, 4s, 8s
        Rails.logger.warn "OpenaiClient: #{e.class} on attempt #{attempts}, retrying in #{delay}s..."
        sleep delay
        retry
      else
        Rails.logger.error "OpenaiClient: #{e.class} after #{attempts} attempts, giving up"
        raise
      end
    end
  end

  class << self
    def call(context, model: nil)
      instrument do
        new.call(context, model: model)
      end
    end

    def instrument
      start_time = Time.zone.now
      yield
    ensure
      end_time = Time.zone.now
      duration = end_time - start_time
      Rails.logger.debug "OpenaiClient call took #{duration.round(2)} seconds"
    end

    def client
      @client ||= Faraday.new(url: TradeTariffBackend.openai_api_base_url) do |faraday|
        faraday.adapter Faraday.default_adapter
        faraday.headers['Accept'] = 'application/json'
        faraday.headers['Content-Type'] = 'application/json'
        faraday.headers['Authorization'] = "Bearer #{TradeTariffBackend.openai_api_key}"
        faraday.headers['User-Agent'] = TradeTariffBackend.user_agent
        faraday.response :json, content_type: /\bjson$/
        faraday.options.timeout = TradeTariffBackend.openai_api_timeout
        faraday.options.open_timeout = TradeTariffBackend.openai_api_open_timeout
      end
    end
  end

  MODEL_CONFIGS = {
    # GPT-5 Series (flagship models)
    'gpt-5.2' => { reasoning_effort: 'high' },             # Latest flagship model
    'gpt-5.1-2025-11-13' => { reasoning_effort: 'none' },  # Extended caching & coding
    'gpt-5-2025-08-07' => { reasoning_effort: 'high' },    # Base GPT-5

    # o-Series (reasoning models)
    'o4-mini-2025-04-16' => { reasoning_effort: 'high' },  # Latest small reasoning model
    'o3-2025-04-16' => { reasoning_effort: 'high' },       # Full o3 reasoning model
    'o3-pro' => { reasoning_effort: 'high' },              # Pro version for complex reasoning

    # GPT-4.1 Series (1M token context)
    'gpt-4.1-2025-04-14' => {},      # Improved instruction following, 1M context
    'gpt-4.1-mini-2025-04-14' => {}, # Mini variant, 1M context
    'gpt-4.1-nano-2025-04-14' => {}, # Nano variant, 1M context

    # GPT-4 Series (legacy)
    'gpt-4o' => {},                # Multimodal GPT-4o
    'gpt-4o-mini' => {},           # Efficient mini variant
  }.freeze
end
