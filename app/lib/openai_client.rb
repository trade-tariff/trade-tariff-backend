class OpenaiClient
  include RetrySupport::WithRetry

  class ApiError < StandardError
    attr_reader :status, :body, :ai_usage

    def initialize(status:, body:, ai_usage: nil)
      @status = status
      @body = body
      @ai_usage = ai_usage
      super("OpenAI API error status=#{status}")
    end
  end

  class RateLimitError < ApiError
    attr_reader :retry_after

    def initialize(status:, body:, retry_after: nil, ai_usage: nil)
      @retry_after = retry_after&.to_f
      super(status: status, body: body, ai_usage:)
    end
  end

  # The HTTP request succeeded, but the Responses API reports that the model
  # did not finish (body `status` is not `completed`).
  class ResponseStatusError < ApiError
    attr_reader :response_status, :reason

    def initialize(status:, body:, response_status:, reason: nil, ai_usage: nil)
      super(status:, body:, ai_usage:)
      @response_status = response_status
      @reason = reason
    end

    def message
      ["OpenAI response status=#{response_status || 'missing'}", ("reason=#{reason}" if reason)].compact.join(' ')
    end
  end

  # Retried like other API errors.
  class ResponseFailedError < ResponseStatusError; end

  # Not retried: the same request stops at the same limit again.
  class ResponseIncompleteError < ResponseStatusError; end

  class DeadlineExceeded < StandardError
    attr_reader :elapsed_seconds, :ai_usage

    def initialize(timeout_seconds:, elapsed_seconds:, ai_usage: nil)
      @elapsed_seconds = elapsed_seconds.to_f
      @ai_usage = ai_usage
      super("OpenAI operation exceeded #{(timeout_seconds.to_f * 1000).round}ms deadline")
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

  def call(context, model: nil, reasoning_effort: nil, event_kind: nil, timeout: nil)
    timeout = timeout.to_f if timeout.present?
    timeout = nil unless timeout&.positive?
    started_at = monotonic_time
    deadline = started_at + timeout if timeout

    messages = if context.is_a?(Array)
                 context
               else
                 [{ role: 'user', content: context.to_s }]
               end

    model ||= TradeTariffBackend.ai_model

    # Usage from earlier attempts that the provider billed (for example a
    # `failed` response that consumed input tokens). It is added to the usage
    # of the final result or error.
    prior_usage = nil
    attempt_usage = nil
    usage_so_far = -> { AiUsage.merge_metadata(prior_usage, attempt_usage) }

    with_retry(
      max_attempts: MAX_RETRIES,
      retryable_errors: RETRYABLE_ERRORS,
      delay_calculator: method(:calculate_retry_delay),
      on_retry: lambda { |attempt:, delay:, error:, **|
        raise error if error.is_a?(ResponseIncompleteError)

        prior_usage = usage_so_far.call if usage_reported?(attempt_usage)
        attempt_usage = nil
        raise_deadline_if_elapsed!(deadline:, timeout:, started_at:, ai_usage: prior_usage)
        raise_if_delay_exceeds_deadline!(delay:, deadline:, timeout:, started_at:, ai_usage: prior_usage)
        Rails.logger.warn "OpenaiClient: #{error.class} on attempt #{attempt}, retrying in #{delay}s..."
      },
      on_exhausted: lambda { |attempt:, error:, **|
        raise_deadline_if_elapsed!(deadline:, timeout:, started_at:, ai_usage: usage_so_far.call)
        Rails.logger.error "OpenaiClient: #{error.class} after #{attempt} attempts, giving up"
      },
    ) do
      remaining = remaining_time(deadline)
      raise_deadline!(timeout:, started_at:, ai_usage: prior_usage) if deadline && remaining <= 0

      response = complete(messages, model:, reasoning_effort:, remaining:)
      attempt_usage = usage_metadata(response, model:, event_kind:, reasoning_effort:)
      raise_on_error!(response, ai_usage: usage_so_far.call) unless response.success?
      raise_on_unfinished_response!(response, ai_usage: usage_so_far.call)

      json = output_text(response.body)
      result = begin
        JSON.parse(json)
      rescue StandardError
        json
      end

      raise_deadline!(timeout:, started_at:, ai_usage: usage_so_far.call) if deadline && remaining_time(deadline) <= 0
      AiUsage.attach_metadata(result, usage_so_far.call)
    end
  end

private

  # Sends one attempt through RubyLLM. Retries, deadlines, usage and errors
  # stay in #call, so the attempt returns the provider's response unchanged.
  #
  # The chat holds no messages. RubyLLM accepts fewer roles and content shapes
  # than the Responses API, and #complete sends nothing when the transcript
  # does not end with a user message. #generate always sends one request, and
  # #keep_request_format adds the caller's messages to it unchanged.
  def complete(messages, model:, reasoning_effort:, remaining:)
    timeout, open_timeout = transport_timeouts(remaining)

    OpenaiTransport.request(timeout:, open_timeout:) do |llm|
      chat = llm.chat(model:, provider: :openai, assume_model_exists: true)
      chat.with_thinking(effort: reasoning_effort) if reasoning_effort.present?
      chat.with_end_user(TradeTariffBackend.openai_user)
          .with_provider_options(text: { format: { type: 'json_object' } })
          .before_request { |payload| keep_request_format(payload, messages) }
          .generate
    end
  end

  # RubyLLM sends system messages as instructions and asks for encrypted
  # reasoning. Keep the request that the models have always received,
  # including the opt-out from provider storage.
  def keep_request_format(payload, messages)
    payload.except!(:instructions, :stream, :include)
    payload[:input] = messages
    payload[:store] = false
  end

  def transport_timeouts(remaining)
    timeout = TradeTariffBackend.openai_api_timeout
    open_timeout = TradeTariffBackend.openai_api_open_timeout
    return [timeout, open_timeout] unless remaining

    scale = [remaining / (timeout.to_f + open_timeout.to_f), 1.0].min

    [timeout.to_f * scale, open_timeout.to_f * scale]
  end

  def raise_on_error!(response, ai_usage:)
    if response.status == 429
      retry_after = response.headers['Retry-After'] || response.headers['retry-after']
      raise RateLimitError.new(status: response.status, body: response.body, retry_after: retry_after, ai_usage:)
    end

    raise ApiError.new(status: response.status, body: response.body, ai_usage:)
  end

  def raise_on_unfinished_response!(response, ai_usage:)
    body = response_body_hash(response)
    response_status = body['status']
    return if response_status == 'completed'

    error_class = response_status == 'incomplete' ? ResponseIncompleteError : ResponseFailedError
    raise error_class.new(
      status: response.status,
      body: response.body,
      response_status:,
      reason: unfinished_reason(body),
      ai_usage:,
    )
  end

  def usage_reported?(metadata)
    metadata.present? && (metadata.input_tokens || metadata.total_tokens).present?
  end

  def unfinished_reason(body)
    body.dig('incomplete_details', 'reason').presence || (body['error']['code'].presence if body['error'].is_a?(Hash))
  end

  def usage_metadata(response, model:, event_kind:, reasoning_effort: nil)
    body = response_body_hash(response)

    extras = response_metadata(body, response, reasoning_effort:)
    error = body['error']
    usage = body['usage'] || (error['usage'] if error.is_a?(Hash))
    return if usage.nil? && extras.empty?

    AiUsage.metadata_for(model:, event_kind:, usage: usage || {}, **extras)
  end

  def response_body_hash(response)
    body = response.respond_to?(:body) ? response.body : response
    body.is_a?(Hash) ? body : {}
  end

  def response_metadata(body, response, reasoning_effort:)
    {
      finish_reason: finish_reason(body),
      served_model: body['model'],
      service_tier: body['service_tier'],
      reasoning_effort: reasoning_effort.presence,
      openai_request_id: openai_request_id(response),
      openai_response_id: body['id'].presence,
    }.compact
  end

  def output_text(body)
    return '' unless body.is_a?(Hash)

    Array(body['output'])
      .select { |item| item['type'] == 'message' }
      .flat_map { |item| Array(item['content']) }
      .select { |content| content['type'] == 'output_text' }
      .map { |content| content['text'] }
      .join
  end

  def finish_reason(body)
    unfinished_reason(body) || body['status']
  end

  def openai_request_id(response)
    return unless response.respond_to?(:headers)

    response.headers['x-request-id'].presence || response.headers['openai-request-id'].presence
  end

  def raise_deadline_if_elapsed!(deadline:, timeout:, started_at:, ai_usage: nil)
    raise_deadline!(timeout:, started_at:, ai_usage:) if deadline && remaining_time(deadline) <= 0
  end

  def raise_if_delay_exceeds_deadline!(delay:, deadline:, timeout:, started_at:, ai_usage: nil)
    return unless deadline

    remaining = remaining_time(deadline)
    raise_deadline!(timeout:, started_at:, ai_usage:) if delay >= remaining
  end

  def remaining_time(deadline)
    deadline && deadline - monotonic_time
  end

  def raise_deadline!(timeout:, started_at:, ai_usage: nil)
    raise DeadlineExceeded.new(
      timeout_seconds: timeout,
      elapsed_seconds: monotonic_time - started_at,
      ai_usage:,
    )
  end

  def monotonic_time
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
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
    def call(context, model: nil, reasoning_effort: nil, event_kind: nil, timeout: nil)
      instrument do
        new.call(context, model: model, reasoning_effort: reasoning_effort, event_kind:, timeout:)
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
  end

  MODEL_CONFIGS = {
    # GPT-6 family (1M context)
    'gpt-6-astra' => { reasoning_levels: %w[low medium high xhigh max] },
    'gpt-6.1-sol' => { reasoning_levels: %w[low medium high xhigh max] },
    'gpt-6.1-terra' => { reasoning_levels: %w[none low medium high xhigh max] },
    'gpt-6-luna' => { reasoning_levels: %w[none low medium high xhigh max] },

    # GPT-5.6 family (1M context)
    'gpt-5.6' => { reasoning_levels: %w[none low medium high xhigh max] },
    'gpt-5.6-terra' => { reasoning_levels: %w[none low medium high xhigh max] },
    'gpt-5.6-luna' => { reasoning_levels: %w[none low medium high xhigh max] },

    # GPT-5.5 (1M context)
    'gpt-5.5' => { reasoning_levels: %w[none low medium high xhigh] },

    # GPT-5.4 (1M context)
    'gpt-5.4' => { reasoning_levels: %w[none low medium high xhigh] },
    'gpt-5.4-mini' => { reasoning_levels: %w[none low medium high xhigh] },
    'gpt-5.4-nano' => { reasoning_levels: %w[none low medium high xhigh] },

    # GPT-5 Series
    'gpt-5.2' => { reasoning_levels: %w[none low medium high] },
    'gpt-5.1-2025-11-13' => { reasoning_levels: %w[none low medium high] },
    'gpt-5-2025-08-07' => { reasoning_levels: %w[minimal low medium high] },
    'gpt-5-mini-2025-08-07' => { reasoning_levels: %w[minimal low medium high] },
    'gpt-5-nano-2025-08-07' => { reasoning_levels: %w[minimal low medium high] },

    # o-Series (reasoning models)
    'o3-2025-04-16' => { reasoning_levels: %w[low medium high] },
    'o3-pro' => { reasoning_levels: %w[low medium high] },

    # GPT-4.1 Series (1M token context)
    'gpt-4.1-2025-04-14' => { reasoning_levels: [] },
    'gpt-4.1-mini-2025-04-14' => { reasoning_levels: [] },

    # GPT-4 Series (legacy)
    'gpt-4o' => { reasoning_levels: [] },
    'gpt-4o-mini' => { reasoning_levels: [] },
  }.freeze
end
