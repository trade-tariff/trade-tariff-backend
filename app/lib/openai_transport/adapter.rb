module OpenaiTransport
  # The Net::HTTP adapter with the default headers and per-request timeouts of
  # the Faraday clients that came before RubyLLM. RubyLLM sets one timeout for
  # each shared connection, it cannot set default headers for embedding
  # requests, and it does not send requests without an API key.
  class Adapter < Faraday::Adapter::NetHttp
    def call(env)
      env.request_headers.update(OpenaiTransport.headers)
      Fiber[TIMEOUTS]&.each { |name, seconds| env.request[name] = seconds }
      super.tap { env[RAW_RESPONSE_HEADERS] = env.response_headers.dup }
    end
  end
end
