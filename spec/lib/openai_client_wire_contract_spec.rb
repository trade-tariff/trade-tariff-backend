RSpec.describe OpenaiClient, :ai_wire_contract do
  responses = AiWireContract::Responses
  ssl_error = OpenSSL::SSL::SSLError.new('SSL_connect returned=1 errno=0 state=error: unexpected eof while reading')
  system_and_user = [
    { role: 'system', content: 'You classify goods. Return JSON.' },
    { role: 'user', content: JSON.generate('description' => 'Cotton T-shirt, knitted', 'codes' => %w[6109100010 6109100090]) },
  ]
  error_body = ->(code, message, extra = {}) { { 'error' => { 'message' => message, 'type' => code, 'param' => nil, 'code' => code }.merge(extra) } }
  failed_body = lambda do |message: 'The model failed to respond.', usage: { 'input_tokens' => 40, 'output_tokens' => 0, 'total_tokens' => 40 }|
    responses.response_body(status: 'failed', output: [], usage:, error: { 'code' => 'server_error', 'message' => message }.compact)
  end

  scenarios = {
    # Inputs
    'string context with default options' => {
      call: -> { described_class.call('What is the capital of France?') },
      script: [responses.completed],
    },
    'instance call with system and user messages and every option' => {
      call: -> { described_class.new.call(system_and_user, model: 'gpt-5.4-mini', reasoning_effort: 'high', event_kind: 'atar_fact_extraction') },
      script: [responses.completed('[{"fact":"knitted"}]')],
    },
    'string context with characters that JSON encoders escape differently' => {
      call: -> { described_class.call("<b>Cafe\u0301 & \"naive\"</b> \u{1F6A2}\u2028line\u2029end\ttab \\ slash", event_kind: 'interactive_search') },
      script: [responses.completed],
    },
    'empty string context' => {
      call: -> { described_class.call('', event_kind: 'interactive_search') },
      script: [responses.completed],
    },
    'conversation with an assistant turn' => {
      call: -> { described_class.call([*system_and_user, { role: 'assistant', content: '{"questions":[]}' }, { role: 'user', content: 'Try again' }]) },
      script: [responses.completed],
    },
    'unknown model with the max reasoning effort' => {
      call: -> { described_class.call('Classify this', model: 'gpt-6.1-terra', reasoning_effort: 'max', event_kind: 'label_generation') },
      script: [responses.completed],
    },
    'default model with a reasoning effort' => {
      call: -> { described_class.call('Classify this', model: nil, reasoning_effort: 'low', event_kind: 'label_generation') },
      script: [responses.completed],
    },
    'blank reasoning effort' => {
      call: -> { described_class.call('Classify this', model: 'gpt-5.2', reasoning_effort: '', event_kind: 'label_generation') },
      script: [responses.completed],
    },
    'reasoning effort without other options' => {
      call: -> { described_class.call('Classify this', reasoning_effort: 'medium') },
      script: [responses.completed],
    },
    'zero timeout is ignored' => {
      call: -> { described_class.call('Classify this', timeout: 0) },
      script: [responses.completed],
    },
    'negative timeout is ignored' => {
      call: -> { described_class.call('Classify this', timeout: -1) },
      script: [responses.completed],
    },
    'evaluation timeout' => {
      call: -> { described_class.call(system_and_user, model: 'gpt-5.4', event_kind: 'evaluation_gold_query_generation', timeout: 60) },
      script: [responses.completed(duration: 12.5)],
    },
    'query expansion timeout' => {
      call: -> { described_class.call('Expand: cotton shirts', model: 'gpt-5.4-mini', reasoning_effort: 'none', event_kind: 'search_query_expansion', timeout: 5.0) },
      script: [responses.completed('{"added_terms":["t-shirts"],"reason":"synonym"}', duration: 1.2)],
    },

    # Response bodies
    'completed JSON array' => {
      call: -> { described_class.call('List facts', event_kind: 'atar_fact_extraction') },
      script: [responses.completed('[{"fact":"one"},{"fact":"two"}]')],
    },
    'completed text that is not JSON' => {
      call: -> { described_class.call('Say hello', event_kind: 'interactive_search') },
      script: [responses.completed('Paris is the capital of France.')],
    },
    'completed JSON inside a markdown fence' => {
      call: -> { described_class.call('Say hello', event_kind: 'interactive_search') },
      script: [responses.completed("```json\n{\"capital\":\"Paris\"}\n```")],
    },
    'completed with several messages, parts and a refusal' => {
      call: -> { described_class.call('Say hello', event_kind: 'interactive_search') },
      script: [
        responses.json(
          responses.response_body(output: [
            responses.reasoning,
            { 'id' => 'msg_1',
              'type' => 'message',
              'role' => 'assistant',
              'content' => [
                { 'type' => 'output_text', 'text' => '{"capital":', 'annotations' => [] },
                { 'type' => 'refusal', 'refusal' => 'I cannot help with that.' },
                { 'type' => 'output_text', 'text' => '"Paris"', 'annotations' => [] },
              ] },
            { 'id' => 'msg_2', 'type' => 'message', 'role' => 'assistant', 'content' => [{ 'type' => 'output_text', 'text' => '}', 'annotations' => [] }] },
          ]),
          headers: AiWireContract::Responses::METADATA_HEADERS,
        ),
      ],
    },
    'completed with only a refusal' => {
      call: -> { described_class.call('Say hello', event_kind: 'interactive_search') },
      script: [responses.json(responses.response_body(output: [responses.message('I cannot help with that.', type: 'refusal')]))],
    },
    'completed with empty output' => {
      call: -> { described_class.call('Say hello', event_kind: 'interactive_search') },
      script: [responses.json(responses.response_body(output: []))],
    },
    'completed without output or usage' => {
      call: -> { described_class.call('Say hello', event_kind: 'interactive_search') },
      script: [responses.json({ 'status' => 'completed' })],
    },
    'completed without usage' => {
      call: -> { described_class.call('Say hello', event_kind: 'interactive_search') },
      script: [responses.json(responses.response_body(usage: nil), headers: AiWireContract::Responses::METADATA_HEADERS)],
    },
    'openai-request-id header and cache write tokens' => {
      call: -> { described_class.call('Say hello', model: 'gpt-6.1-sol', event_kind: 'interactive_search') },
      script: [
        responses.json(
          responses.response_body(usage: {
            'input_tokens' => 2_000,
            'input_tokens_details' => { 'cached_tokens' => 500, 'cache_write_tokens' => 1_000 },
            'output_tokens' => 50,
            'total_tokens' => 2_050,
          }),
          headers: { 'openai-request-id' => 'req_alternative' },
        ),
      ],
    },
    'long context pricing' => {
      call: -> { described_class.call('Long prompt', model: 'gpt-6.1-sol', event_kind: 'interactive_search') },
      script: [responses.json(responses.response_body(usage: { 'input_tokens' => 300_000, 'output_tokens' => 1_000, 'total_tokens' => 301_000 }))],
    },
    'model without pricing' => {
      call: -> { described_class.call('Prompt', model: 'gpt-6.1-terra', event_kind: 'interactive_search') },
      script: [responses.completed],
    },

    # Unfinished responses
    'incomplete at the output token limit' => {
      call: -> { described_class.call('test', model: 'gpt-test', event_kind: 'interactive_search') },
      script: [responses.json(responses.response_body(status: 'incomplete', incomplete_details: { 'reason' => 'max_output_tokens' }, output: [responses.message('{"capital":"Par')]))],
    },
    'incomplete after a content filter' => {
      call: -> { described_class.call('test', event_kind: 'interactive_search') },
      script: [responses.json(responses.response_body(status: 'incomplete', incomplete_details: { 'reason' => 'content_filter' }, output: []))],
    },
    'failed then completed' => {
      call: -> { described_class.call('test', event_kind: 'interactive_search') },
      script: [responses.json(failed_body.call), responses.completed],
    },
    'failed on every attempt' => {
      call: -> { described_class.call('test', event_kind: 'interactive_search') },
      script: Array.new(3) { responses.json(failed_body.call) },
    },
    'failed without an error message then completed' => {
      call: -> { described_class.call('test', event_kind: 'interactive_search') },
      script: [responses.json(responses.response_body(status: 'failed', output: [], usage: nil, error: { 'code' => 'server_error' })), responses.completed],
    },
    'missing response status' => {
      call: -> { described_class.call('test', event_kind: 'interactive_search') },
      script: Array.new(3) { responses.json(responses.response_body(status: nil)) },
    },
    'HTML body with HTTP 200' => {
      call: -> { described_class.call('test', event_kind: 'interactive_search') },
      script: Array.new(3) { responses.raw('<html>Gateway</html>', status: 200, content_type: 'text/html') },
    },
    'JSON array body with HTTP 200' => {
      call: -> { described_class.call('test', event_kind: 'interactive_search') },
      script: Array.new(3) { responses.json('[]') },
    },
    'empty JSON body with HTTP 200' => {
      call: -> { described_class.call('test', event_kind: 'interactive_search') },
      script: Array.new(3) { responses.json('') },
    },
    'invalid JSON body with HTTP 200' => {
      call: -> { described_class.call('test', event_kind: 'interactive_search') },
      script: [responses.json('{"status":')],
    },

    # HTTP errors
    'bad request with usage' => {
      call: -> { described_class.call('test', event_kind: 'interactive_search') },
      script: Array.new(3) { responses.json(error_body.call('invalid_request_error', 'Invalid value for reasoning.effort', 'usage' => { 'input_tokens' => 12, 'total_tokens' => 12 }), status: 400) },
    },
    'context length exceeded' => {
      call: -> { described_class.call('test', event_kind: 'interactive_search') },
      script: Array.new(3) { responses.json(error_body.call('context_length_exceeded', 'Your input exceeds the context window of this model.'), status: 400) },
    },
    'unauthorised' => {
      call: -> { described_class.call('test', event_kind: 'interactive_search') },
      script: Array.new(3) { responses.json(error_body.call('invalid_api_key', 'Incorrect API key provided.'), status: 401) },
    },
    'payment required' => {
      call: -> { described_class.call('test') },
      script: Array.new(3) { responses.json(error_body.call('insufficient_quota', 'You exceeded your current quota.'), status: 402) },
    },
    'forbidden' => {
      call: -> { described_class.call('test') },
      script: Array.new(3) { responses.json(error_body.call('unsupported_country_region_territory', 'Country not supported.'), status: 403) },
    },
    'not found' => {
      call: -> { described_class.call('test', model: 'gpt-missing') },
      script: Array.new(3) { responses.json(error_body.call('model_not_found', 'The model gpt-missing does not exist.'), status: 404) },
    },
    'conflict' => {
      call: -> { described_class.call('test') },
      script: Array.new(3) { responses.json(error_body.call('conflict', 'Conflict.'), status: 409) },
    },
    'payload too large' => {
      call: -> { described_class.call('test') },
      script: Array.new(3) { responses.json(error_body.call('request_too_large', 'Request too large.'), status: 413) },
    },
    'unprocessable entity' => {
      call: -> { described_class.call('test') },
      script: Array.new(3) { responses.json(error_body.call('invalid_request_error', 'Unprocessable.'), status: 422) },
    },
    'server error with usage on every attempt' => {
      call: -> { described_class.call('test', model: 'gpt-test', event_kind: 'interactive_search') },
      script: Array.new(3) { responses.json({ 'error' => 'Internal Server Error', 'usage' => { 'input_tokens' => 60, 'total_tokens' => 60 } }, status: 500) },
    },
    'bad gateway then completed' => {
      call: -> { described_class.call('test', event_kind: 'interactive_search') },
      script: [responses.json(error_body.call('server_error', 'Bad gateway'), status: 502), responses.completed],
    },
    'service unavailable then gateway timeout then completed' => {
      call: -> { described_class.call('test', event_kind: 'interactive_search') },
      script: [responses.json(error_body.call('server_error', 'Unavailable'), status: 503), responses.json(error_body.call('server_error', 'Timeout'), status: 504), responses.completed],
    },
    'overloaded' => {
      call: -> { described_class.call('test') },
      script: Array.new(3) { responses.json(error_body.call('overloaded', 'Overloaded'), status: 529) },
    },
    'plain text server error' => {
      call: -> { described_class.call('test') },
      script: Array.new(3) { responses.raw('upstream connect error', status: 503, content_type: 'text/plain') },
    },
    'invalid JSON server error' => {
      call: -> { described_class.call('test') },
      script: [responses.json('{"error":', status: 500)],
    },
    'redirect' => {
      call: -> { described_class.call('test') },
      script: Array.new(3) { responses.raw('', status: 302, content_type: 'text/html', headers: { 'Location' => 'https://example.com/' }) },
    },

    # Rate limits
    'rate limited with Retry-After then completed' => {
      call: -> { described_class.call('test', event_kind: 'interactive_search') },
      script: [responses.json(error_body.call('rate_limit_exceeded', 'Rate limit reached'), status: 429, headers: { 'Retry-After' => '5' }), responses.completed],
    },
    'rate limited with a long Retry-After then completed' => {
      call: -> { described_class.call('test', event_kind: 'interactive_search') },
      script: [responses.json(error_body.call('rate_limit_exceeded', 'Rate limit reached'), status: 429, headers: { 'Retry-After' => '120' }), responses.completed],
    },
    'rate limited with only OpenAI reset headers then completed' => {
      call: -> { described_class.call('test', event_kind: 'interactive_search') },
      script: [
        responses.json(error_body.call('rate_limit_exceeded', 'Rate limit reached'), status: 429, headers: {
          'retry-after-ms' => '1500', 'x-ratelimit-reset-requests' => '6m0s', 'x-ratelimit-reset-tokens' => '7.66s'
        }),
        responses.completed,
      ],
    },
    'rate limited with an HTTP date Retry-After then completed' => {
      call: -> { described_class.call('test', event_kind: 'interactive_search') },
      script: [responses.json(error_body.call('rate_limit_exceeded', 'Rate limit reached'), status: 429, headers: { 'Retry-After' => 'Wed, 21 Oct 2026 07:28:00 GMT' }), responses.completed],
    },
    'rate limited on every attempt' => {
      call: -> { described_class.call('test', event_kind: 'interactive_search') },
      script: Array.new(3) { responses.json(error_body.call('rate_limit_exceeded', 'Rate limit reached'), status: 429, headers: { 'Retry-After' => '1' }) },
    },
    'rate limited with a quota message' => {
      call: -> { described_class.call('test') },
      script: Array.new(3) { responses.json(error_body.call('insufficient_quota', 'You exceeded your current quota, please check your plan and billing details.'), status: 429) },
    },

    # Transport errors
    'TLS error then completed' => {
      call: -> { described_class.call('test', event_kind: 'interactive_search') },
      script: [responses.failure(ssl_error), responses.completed],
    },
    'TLS error on every attempt' => {
      call: -> { described_class.call('test', event_kind: 'interactive_search') },
      script: Array.new(3) { responses.failure(ssl_error) },
    },
    'read timeout on every attempt' => {
      call: -> { described_class.call('test', event_kind: 'interactive_search') },
      script: Array.new(3) { responses.failure(Net::ReadTimeout) },
    },
    'open timeout then completed' => {
      call: -> { described_class.call('test', event_kind: 'interactive_search') },
      script: [responses.failure(Net::OpenTimeout), responses.completed],
    },
    'connection refused then reset then completed' => {
      call: -> { described_class.call('test', event_kind: 'interactive_search') },
      script: [responses.failure(Errno::ECONNREFUSED), responses.failure(Errno::ECONNRESET), responses.completed],
    },

    # Operation deadlines
    'transient TLS error inside the deadline' => {
      call: -> { described_class.call('test', event_kind: 'search_query_expansion', timeout: 5) },
      script: [responses.failure(ssl_error, duration: 0.25), responses.completed(duration: 0.5)],
    },
    'retry backoff exhausts the deadline' => {
      call: -> { described_class.call('test', event_kind: 'search_query_expansion', timeout: 1) },
      script: [responses.failure(ssl_error)],
    },
    'transport timeout at the deadline' => {
      call: -> { described_class.call('test', event_kind: 'search_query_expansion', timeout: 5) },
      script: [responses.failure(Net::ReadTimeout, duration: 5.0)],
    },
    'response after the deadline' => {
      call: -> { described_class.call('test', event_kind: 'search_query_expansion', timeout: 5) },
      script: [responses.completed(duration: 5.01)],
    },
    'retries exhausted after the deadline' => {
      call: -> { described_class.call('test', event_kind: 'search_query_expansion', timeout: 10) },
      script: [responses.failure(ssl_error), responses.failure(ssl_error, duration: 1.0), responses.failure(ssl_error, duration: 4.0)],
    },
    'Retry-After longer than the remaining deadline' => {
      call: -> { described_class.call('test', event_kind: 'search_query_expansion', timeout: 1) },
      script: [responses.json(error_body.call('rate_limit_exceeded', 'Rate limit reached'), status: 429, headers: { 'Retry-After' => '5' })],
    },
    'failed attempt usage added to a deadline error' => {
      call: -> { described_class.call('test', model: 'gpt-test', event_kind: 'interactive_search', timeout: 1) },
      script: [responses.json(failed_body.call(usage: { 'input_tokens' => 40, 'output_tokens' => 0, 'total_tokens' => 40 }), duration: 0.5)],
    },
    'incomplete inside the deadline' => {
      call: -> { described_class.call('test', event_kind: 'search_query_expansion', timeout: 5) },
      script: [responses.json(responses.response_body(status: 'incomplete', incomplete_details: { 'reason' => 'max_output_tokens' }), duration: 1.0)],
    },
  }.freeze

  scenarios.each do |name, scenario|
    it name do
      observation = observe_ai_call(url: AiWireContract::RESPONSES_URL, script: scenario.fetch(:script)) do
        instance_exec(&scenario.fetch(:call))
      end

      expect_wire_contract('openai_client', name, observation)
    end
  end

  it 'covers every reasoning effort that admin configuration can select' do
    efforts = described_class::MODEL_CONFIGS.values.flat_map { |config| config[:reasoning_levels] }.uniq.sort

    efforts.each do |effort|
      observation = observe_ai_call(url: AiWireContract::RESPONSES_URL, script: [responses.completed]) do
        described_class.call('Classify this', model: 'gpt-5.2', reasoning_effort: effort, event_kind: 'label_generation')
      end

      expect_wire_contract('openai_client', "reasoning effort #{effort}", observation)
    end
  end
end
