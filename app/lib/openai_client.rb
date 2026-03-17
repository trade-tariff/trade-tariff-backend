class OpenaiClient
  class ApiError < StandardError
    attr_reader :status, :body

    def initialize(status:, body:)
      @status = status
      @body = body
      super("OpenAI API error (HTTP #{status}): #{body}")
    end
  end

  class RateLimitError < ApiError
    attr_reader :retry_after

    def initialize(status:, body:, retry_after: nil)
      @retry_after = retry_after&.to_f
      super(status: status, body: body)
    end
  end

  MAX_RETRIES = 3
  MAX_RETRY_DELAY = 60 # seconds
  RETRY_DELAY = 2 # seconds
  RETRYABLE_ERRORS = [
    ApiError,
    Faraday::TimeoutError,
    Faraday::ConnectionFailed,
    Faraday::SSLError,
    Net::ReadTimeout,
    Net::OpenTimeout,
  ].freeze

  def call(context, model: nil, reasoning_effort: nil)
    messages = if context.is_a?(Array)
                 context
               else
                 [{ role: 'user', content: context.to_s }]
               end

    model ||= TradeTariffBackend.ai_model

    body = {
      model: model,
      messages: messages,
      user: TradeTariffBackend.openai_user,
      response_format: { type: 'json_object' },
    }
    body[:reasoning_effort] = reasoning_effort if reasoning_effort.present?
    body = body.to_json

    with_retry do
      response = self.class.client.post('chat/completions', body)

      raise_on_error!(response) unless response.success?

      json = response.body.dig('choices', 0, 'message', 'content') || ''

      begin
        JSON.parse(json)
      rescue StandardError
        json
      end
    end
  end

  private

  def raise_on_error!(response)
    if response.status == 429
      retry_after = response.headers['Retry-After'] || response.headers['retry-after']
      raise RateLimitError.new(status: response.status, body: response.body, retry_after: retry_after)
    end

    raise ApiError.new(status: response.status, body: response.body)
  end

  def with_retry
    attempts = 0

    begin
      attempts += 1
      yield
    rescue *RETRYABLE_ERRORS => e
      if attempts < MAX_RETRIES
        delay = calculate_retry_delay(attempts, e)
        Rails.logger.warn "OpenaiClient: #{e.class} on attempt #{attempts}, retrying in #{delay}s..."
        sleep delay
        retry
      else
        Rails.logger.error "OpenaiClient: #{e.class} after #{attempts} attempts, giving up"
        raise
      end
    end
  end

  def calculate_retry_delay(attempts, error)
    base_delay = RETRY_DELAY * (2**(attempts - 1))

    if error.is_a?(RateLimitError) && error.retry_after
      [error.retry_after, MAX_RETRY_DELAY].min
    else
      [base_delay, MAX_RETRY_DELAY].min
    end
  end

  class << self
    def call(context, model: nil, reasoning_effort: nil)
      instrument do
        new.call(context, model: model, reasoning_effort: reasoning_effort)
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
    # GPT-5.4 (latest flagship, 1M context)
    'gpt-5.4' => { reasoning_levels: %w[none low medium high xhigh] },

    # GPT-5 Series
    'gpt-5.2' => { reasoning_levels: %w[none low medium high] },
    'gpt-5.1-2025-11-13' => { reasoning_levels: %w[none low medium high] },
    'gpt-5-2025-08-07' => { reasoning_levels: %w[minimal low medium high] },
    'gpt-5-mini-2025-08-07' => { reasoning_levels: %w[minimal low medium high] },
    'gpt-5-nano-2025-08-07' => { reasoning_levels: %w[minimal low medium high] },

    # o-Series (reasoning models)
    'o4-mini-2025-04-16' => { reasoning_levels: %w[low medium high] },
    'o3-2025-04-16' => { reasoning_levels: %w[low medium high] },
    'o3-pro' => { reasoning_levels: %w[low medium high] },

    # GPT-4.1 Series (1M token context)
    'gpt-4.1-2025-04-14' => { reasoning_levels: [] },
    'gpt-4.1-mini-2025-04-14' => { reasoning_levels: [] },
    'gpt-4.1-nano-2025-04-14' => { reasoning_levels: [] },

    # GPT-4 Series (legacy)
    'gpt-4o' => { reasoning_levels: [] },
    'gpt-4o-mini' => { reasoning_levels: [] },
  }.freeze
end
