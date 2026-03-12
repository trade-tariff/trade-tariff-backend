class EmbeddingService
  MODEL = 'text-embedding-3-small'.freeze
  BATCH_SIZE = 100

  MAX_RETRIES = 3
  RETRY_DELAY = 2

  RETRYABLE_ERRORS = [
    Faraday::TimeoutError,
    Faraday::ConnectionFailed,
    Faraday::SSLError,
    Net::ReadTimeout,
    Net::OpenTimeout,
  ].freeze

  RETRYABLE_HTTP_STATUSES = [429, 500, 502, 503, 504].freeze

  class ApiError < StandardError
    attr_reader :http_status

    def initialize(message, http_status: nil)
      @http_status = http_status
      super(message)
    end
  end

  class ServerError < ApiError; end
  class ClientError < ApiError; end

  def embed(text)
    embed_batch([text]).first
  end

  def embed_batch(texts)
    present_indices = []
    filtered_texts = []

    texts.each_with_index do |text, i|
      if text.present?
        present_indices << i
        filtered_texts << text
      end
    end

    return Array.new(texts.size) if filtered_texts.empty?

    embeddings = Array.new(texts.size)

    filtered_texts.each_slice(BATCH_SIZE).each_with_index do |batch, slice_index|
      response = with_retry do
        resp = client.post('embeddings', { model: MODEL, input: batch }.to_json)

        if RETRYABLE_HTTP_STATUSES.include?(resp.status)
          raise ServerError.new("EmbeddingService API error: #{resp.status}", http_status: resp.status)
        end

        resp
      end

      if response.success?
        batch_embeddings = response.body['data']
          .sort_by { |d| d['index'] }
          .map { |d| d['embedding'] }

        batch_embeddings.each_with_index do |embedding, i|
          original_index = present_indices[slice_index * BATCH_SIZE + i]
          embeddings[original_index] = embedding
        end
      else
        raise ClientError.new("EmbeddingService API error: #{response.status} - #{response.body}", http_status: response.status)
      end
    end

    embeddings
  end

  private

  def with_retry
    attempts = 0

    begin
      attempts += 1
      yield
    rescue *RETRYABLE_ERRORS, ServerError => e
      if attempts < MAX_RETRIES
        delay = RETRY_DELAY * (2**(attempts - 1))
        SelfTextGenerator::Instrumentation.embedding_api_retry(attempt: attempts, delay:, error: e)
        sleep delay
        retry
      else
        raise
      end
    end
  end

  def client
    self.class.client
  end

  class << self
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

    def reset_client!
      @client = nil
    end
  end
end
