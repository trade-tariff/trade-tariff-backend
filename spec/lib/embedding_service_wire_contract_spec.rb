RSpec.describe EmbeddingService, :ai_wire_contract do
  responses = AiWireContract::Responses
  ssl_error = OpenSSL::SSL::SSLError.new('SSL_connect returned=1 errno=0 state=error: unexpected eof while reading')
  error_body = ->(code, message) { { 'error' => { 'message' => message, 'type' => code, 'param' => nil, 'code' => code } } }
  texts = ->(count) { Array.new(count) { |index| "Commodity description #{index + 1}" } }

  scenarios = {
    'single text' => {
      call: -> { described_class.new.embed('Live horses for breeding', event_kind: 'vector_search_query_embedding') },
      script: [responses.embeddings(1)],
    },
    'single text without an event kind' => {
      call: -> { described_class.new.embed('Live horses for breeding') },
      script: [responses.embeddings(1)],
    },
    'single blank text' => {
      call: -> { described_class.new.embed('   ', event_kind: 'vector_search_query_embedding') },
      script: [],
    },
    'single text with characters that JSON encoders escape differently' => {
      call: -> { described_class.new.embed("<b>Cafe\u0301 & \"naive\"</b> \u{1F6A2}\u2028line", event_kind: 'vector_search_query_embedding') },
      script: [responses.embeddings(1)],
    },
    'small batch' => {
      call: -> { described_class.new.embed_batch(texts.call(3), event_kind: 'label_scoring_embedding') },
      script: [responses.embeddings(3)],
    },
    'batch with blank and missing texts' => {
      call: -> { described_class.new.embed_batch(['Horses', nil, '', 'Cattle', '  ', 'Sheep'], event_kind: 'self_text_scoring_embedding') },
      script: [responses.embeddings(3)],
    },
    'batch of only blank texts' => {
      call: -> { described_class.new.embed_batch([nil, '', ' '], event_kind: 'self_text_scoring_embedding') },
      script: [],
    },
    'empty batch' => {
      call: -> { described_class.new.embed_batch([], event_kind: 'self_text_scoring_embedding') },
      script: [],
    },
    'batch larger than the request limit' => {
      call: -> { described_class.new.embed_batch(texts.call(250), event_kind: 'composite_search_embedding') },
      script: [responses.embeddings(100), responses.embeddings(100), responses.embeddings(50)],
    },
    'response indices out of order' => {
      call: -> { described_class.new.embed_batch(texts.call(3), event_kind: 'label_scoring_embedding') },
      script: [responses.embeddings(3, indices: [2, 0, 1])],
    },
    'duplicate response index' => {
      call: -> { described_class.new.embed_batch(texts.call(2), event_kind: 'label_scoring_embedding') },
      script: [responses.embeddings(2, indices: [0, 0])],
    },
    'missing response index' => {
      call: -> { described_class.new.embed_batch(texts.call(3), event_kind: 'label_scoring_embedding') },
      script: [responses.embeddings(2, indices: [0, 2])],
    },
    'too many vectors' => {
      call: -> { described_class.new.embed_batch(texts.call(1), event_kind: 'label_scoring_embedding') },
      script: [responses.embeddings(2)],
    },
    'wrong vector dimensions' => {
      call: -> { described_class.new.embed_batch(texts.call(2), event_kind: 'label_scoring_embedding') },
      script: [responses.embeddings(2, dimensions: 1024)],
    },
    'non-numeric vector value' => {
      call: -> { described_class.new.embed_batch(texts.call(1), event_kind: 'label_scoring_embedding') },
      script: [responses.json({ 'object' => 'list', 'model' => 'text-embedding-3-small', 'data' => [{ 'index' => 0, 'embedding' => Array.new(1536, 'x') }] })],
    },
    'integer vector values' => {
      call: -> { described_class.new.embed_batch(texts.call(1), event_kind: 'label_scoring_embedding') },
      script: [responses.json({ 'object' => 'list', 'model' => 'text-embedding-3-small', 'data' => [{ 'index' => 0, 'embedding' => Array.new(1536, 1) }] })],
    },
    'response without data' => {
      call: -> { described_class.new.embed_batch(texts.call(1), event_kind: 'label_scoring_embedding') },
      script: [responses.json({ 'object' => 'list', 'model' => 'text-embedding-3-small', 'usage' => { 'prompt_tokens' => 4, 'total_tokens' => 4 } })],
    },
    'response data that is not a list' => {
      call: -> { described_class.new.embed_batch(texts.call(1), event_kind: 'label_scoring_embedding') },
      script: [responses.json({ 'object' => 'list', 'data' => { 'index' => 0 } })],
    },
    'HTML body with HTTP 200' => {
      call: -> { described_class.new.embed_batch(texts.call(1), event_kind: 'label_scoring_embedding') },
      script: [responses.raw('<html>Gateway</html>', status: 200, content_type: 'text/html')],
    },
    'empty JSON body with HTTP 200' => {
      call: -> { described_class.new.embed_batch(texts.call(1), event_kind: 'label_scoring_embedding') },
      script: [responses.json('')],
    },
    'invalid JSON body with HTTP 200' => {
      call: -> { described_class.new.embed_batch(texts.call(1), event_kind: 'label_scoring_embedding') },
      script: [responses.json('{"data":')],
    },
    'response without usage or metadata' => {
      call: -> { described_class.new.embed_batch(texts.call(2), event_kind: 'label_scoring_embedding') },
      script: [responses.embeddings(2, usage: nil, model: nil, headers: AiWireContract::Responses::JSON_HEADERS)],
    },
    'response with openai-request-id and a response id' => {
      call: -> { described_class.new.embed_batch(texts.call(2), event_kind: 'label_scoring_embedding') },
      script: [responses.embeddings(2, id: 'emb_contract', headers: { 'openai-request-id' => 'req_alternative' })],
    },
    'rate limited then completed' => {
      call: -> { described_class.new.embed('Live horses', event_kind: 'vector_search_query_embedding') },
      script: [responses.json(error_body.call('rate_limit_exceeded', 'Rate limit reached'), status: 429, headers: { 'Retry-After' => '30', 'x-request-id' => 'req_limited' }), responses.embeddings(1)],
    },
    'server errors then completed' => {
      call: -> { described_class.new.embed_batch(texts.call(2), event_kind: 'self_text_scoring_embedding') },
      script: [
        responses.json(error_body.call('server_error', 'Internal error'), status: 500),
        responses.json(error_body.call('server_error', 'Bad gateway'), status: 502),
        responses.embeddings(2),
      ],
    },
    'unavailable on every attempt' => {
      call: -> { described_class.new.embed_batch(texts.call(2), event_kind: 'self_text_scoring_embedding') },
      script: [
        responses.json(error_body.call('server_error', 'Unavailable'), status: 503),
        responses.json(error_body.call('server_error', 'Gateway timeout'), status: 504),
        responses.raw('upstream connect error', status: 503, content_type: 'text/plain'),
      ],
    },
    'bad request' => {
      call: -> { described_class.new.embed_batch(texts.call(2), event_kind: 'self_text_scoring_embedding') },
      script: [responses.json(error_body.call('invalid_request_error', 'Invalid input'), status: 400, headers: { 'x-request-id' => 'req_rejected' })],
    },
    'unauthorised with a plain text body' => {
      call: -> { described_class.new.embed_batch(texts.call(1), event_kind: 'self_text_scoring_embedding') },
      script: [responses.raw('Unauthorized', status: 401, content_type: 'text/plain')],
    },
    'payload too large' => {
      call: -> { described_class.new.embed_batch(texts.call(1), event_kind: 'composite_search_embedding') },
      script: [responses.json(error_body.call('request_too_large', 'Too many tokens'), status: 413)],
    },
    'server error with an invalid JSON body' => {
      call: -> { described_class.new.embed_batch(texts.call(1), event_kind: 'composite_search_embedding') },
      script: [responses.json('{"error":', status: 500)],
    },
    'TLS error then completed' => {
      call: -> { described_class.new.embed('Live horses', event_kind: 'vector_search_query_embedding') },
      script: [responses.failure(ssl_error), responses.embeddings(1)],
    },
    'read timeout on every attempt' => {
      call: -> { described_class.new.embed('Live horses', event_kind: 'vector_search_query_embedding') },
      script: Array.new(3) { responses.failure(Net::ReadTimeout) },
    },
    'open timeout then connection refused then completed' => {
      call: -> { described_class.new.embed_batch(texts.call(2), event_kind: 'composite_search_embedding') },
      script: [responses.failure(Net::OpenTimeout), responses.failure(Errno::ECONNREFUSED), responses.embeddings(2)],
    },
    'second request rejected after the first succeeded' => {
      call: -> { described_class.new.embed_batch(texts.call(150), event_kind: 'composite_search_embedding') },
      script: [responses.embeddings(100), responses.json(error_body.call('invalid_request_error', 'Invalid input'), status: 400)],
    },
    'second request malformed after the first succeeded' => {
      call: -> { described_class.new.embed_batch(texts.call(150), event_kind: 'composite_search_embedding') },
      script: [responses.embeddings(100), responses.embeddings(49)],
    },
  }.freeze

  scenarios.each do |name, scenario|
    it name do
      observation = observe_ai_call(url: AiWireContract::EMBEDDINGS_URL, script: scenario.fetch(:script)) do
        instance_exec(&scenario.fetch(:call))
      end

      expect_wire_contract('embedding_service', name, observation)
    end
  end
end
