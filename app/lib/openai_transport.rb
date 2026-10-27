# Sends OpenAI requests through RubyLLM with the HTTP contract of the Faraday
# clients that came before it: the same headers, timeouts and bodies on the
# wire. OpenaiClient and EmbeddingService keep their own retries, deadlines,
# usage accounting and error classes, so each request here is one attempt.
# It returns the provider's HTTP response whatever its status, and raises only
# for transport errors.
module OpenaiTransport
  RAW_RESPONSE_HEADERS = :openai_transport_raw_response_headers
  # Like RubyLLM's usage owner, per-request timeouts live in fiber storage.
  # This keeps one shared RubyLLM connection when a deadline changes them.
  TIMEOUTS = :openai_transport_timeouts

module_function

  # Yields a RubyLLM context for one request and returns the response.
  def request(timeout: TradeTariffBackend.openai_api_timeout, open_timeout: TradeTariffBackend.openai_api_open_timeout)
    capture = ResponseCapture.new(RubyLLM.config.instrumenter)

    begin
      with_timeouts(timeout:, open_timeout:) { yield context(instrumenter: capture) }
      capture.response
    rescue RubyLLM::Error => e
      raise unless e.response

      provider_response(e.response)
    rescue StandardError
      # RubyLLM could not read a response that the provider sent. The caller
      # applies its own rules to it.
      raise unless capture.response

      capture.response
    end
  end

  def context(instrumenter:)
    RubyLLM.context do |config|
      # RubyLLM sends nothing without a key. Adapter sends the configured key,
      # so a missing key still gets the provider's 401 response, as before.
      config.openai_api_key = TradeTariffBackend.openai_api_key.presence || 'not configured'
      config.openai_api_base = TradeTariffBackend.openai_api_base_url
      config.request_timeout = TradeTariffBackend.openai_api_timeout
      config.max_retries = 0
      config.faraday_adapter = Adapter
      config.instrumenter = instrumenter
    end
  end

  def with_timeouts(**timeouts)
    previous = Fiber[TIMEOUTS]
    Fiber[TIMEOUTS] = timeouts
    yield
  ensure
    Fiber[TIMEOUTS] = previous
  end

  def headers
    {
      'Accept' => 'application/json',
      'Authorization' => "Bearer #{TradeTariffBackend.openai_api_key}",
      'User-Agent' => TradeTariffBackend.user_agent,
    }
  end

  # RubyLLM raises for an HTTP error before the JSON body is parsed, and it
  # adds a Retry-After header from other rate limit headers. Rebuild the
  # response that the provider sent.
  def provider_response(source)
    env = source.respond_to?(:env) ? source.env : source
    env.response_headers = env[RAW_RESPONSE_HEADERS] if env[RAW_RESPONSE_HEADERS]
    env.body = parse_json(env) if env.body.is_a?(String)
    Faraday::Response.new(env)
  end

  def parse_json(env)
    media_type = env.response_headers['Content-Type'].to_s.split(';', 2).first.to_s
    return env.body unless media_type.match?(/\bjson$/)
    return if env.body.strip.empty?

    JSON.parse(env.body)
  rescue JSON::ParserError => e
    raise Faraday::ParsingError.new(e, Faraday::Response.new(env))
  end
end
