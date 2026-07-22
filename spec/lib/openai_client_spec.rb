RSpec.describe OpenaiClient do
  let(:api_base_url) { 'https://api.openai.com/v1' }
  let(:response_body) do
    {
      'choices' => [
        {
          'message' => {
            'content' => '{"capital":"Paris"}',
          },
        },
      ],
      'usage' => {
        'prompt_tokens' => 1_000,
        'completion_tokens' => 250,
        'total_tokens' => 1_250,
      },
    }
  end

  describe '#call' do
    subject(:client) { described_class.new }

    context 'when given a string context' do
      let(:context) { 'What is the capital of France?' }

      before do
        stub_request(:post, "#{api_base_url}/chat/completions")
          .to_return(status: 200, body: response_body.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns the parsed JSON response' do
        result = client.call(context)
        expect(result).to eq('capital' => 'Paris')
      end

      it 'attaches token usage and cost metadata to the parsed response' do
        allow(TradeTariffBackend).to receive(:openai_model_pricing).and_return({
          TradeTariffBackend.ai_model => { 'input_per_million_tokens' => 2.0, 'output_per_million_tokens' => 8.0 },
        })

        result = client.call(context, event_kind: 'search_query_expansion')

        expect(AiUsage.metadata_from(result).to_h).to include(
          model: TradeTariffBackend.ai_model,
          event_kind: 'search_query_expansion',
          input_tokens: 1_000,
          output_tokens: 250,
          total_tokens: 1_250,
          total_cost_usd: 0.004,
          pricing_known: true,
        )
      end

      it 'sends the context as a user message' do
        client.call(context)

        expect(WebMock).to have_requested(:post, "#{api_base_url}/chat/completions")
          .with(body: hash_including(
            'messages' => [{ 'role' => 'user', 'content' => context }],
          ))
      end
    end

    context 'when given a reasoning_effort parameter' do
      let(:context) { 'What is the capital of France?' }

      before do
        stub_request(:post, "#{api_base_url}/chat/completions")
          .to_return(status: 200, body: response_body.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'includes reasoning_effort in the request body when present' do
        client.call(context, reasoning_effort: 'low')

        expect(WebMock).to have_requested(:post, "#{api_base_url}/chat/completions")
          .with(body: hash_including('reasoning_effort' => 'low'))
      end

      it 'omits reasoning_effort from the request body when nil' do
        client.call(context)

        expect(WebMock).to(have_requested(:post, "#{api_base_url}/chat/completions")
          .with { |req| !JSON.parse(req.body).key?('reasoning_effort') })
      end

      it 'omits reasoning_effort from the request body when blank' do
        client.call(context, reasoning_effort: '')

        expect(WebMock).to(have_requested(:post, "#{api_base_url}/chat/completions")
          .with { |req| !JSON.parse(req.body).key?('reasoning_effort') })
      end
    end

    context 'when given an array of messages' do
      let(:messages) do
        [
          { role: 'system', content: 'You are a helpful assistant.' },
          { role: 'user', content: 'What is the capital of France?' },
        ]
      end

      before do
        stub_request(:post, "#{api_base_url}/chat/completions")
          .to_return(status: 200, body: response_body.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'sends the messages array directly' do
        client.call(messages)

        expect(WebMock).to have_requested(:post, "#{api_base_url}/chat/completions")
          .with(body: hash_including('messages' => messages))
      end
    end

    context 'when the API returns a 500 error response' do
      let(:error_body) do
        {
          error: 'Internal Server Error',
          usage: {
            prompt_tokens: 20,
            completion_tokens: 0,
            total_tokens: 20,
          },
        }
      end

      before do
        allow(Kernel).to receive(:sleep)

        stub_request(:post, "#{api_base_url}/chat/completions")
          .to_return(status: 500, body: error_body.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'raises an ApiError' do
        expect { client.call('test') }.to raise_error(OpenaiClient::ApiError) do |error|
          expect(error.status).to eq(500)
          expect(error.message).to eq('OpenAI API error status=500')
          expect(error.message).not_to include('Internal Server Error')
          expect(error.body['error']).to eq('Internal Server Error')
          expect(error.body.dig('usage', 'prompt_tokens')).to eq(20)
        end
      end

      it 'attaches usage metadata to ApiError when the provider returns usage' do
        expect { client.call('test', model: 'gpt-test', event_kind: 'interactive_search') }
          .to raise_error(OpenaiClient::ApiError) { |error|
            expect(error.ai_usage.to_h).to include(
              model: 'gpt-test',
              event_kind: 'interactive_search',
              input_tokens: 20,
              total_tokens: 20,
            )
          }
      end
    end

    context 'when the API returns a 429 rate limit response' do
      before do
        allow(Kernel).to receive(:sleep)

        stub_request(:post, "#{api_base_url}/chat/completions")
          .to_return(status: 429, body: { error: 'Rate limit exceeded' }.to_json, headers: { 'Content-Type' => 'application/json', 'Retry-After' => '5' })
      end

      it 'raises a RateLimitError with retry_after' do
        expect { client.call('test') }.to raise_error(OpenaiClient::RateLimitError) do |error|
          expect(error.status).to eq(429)
          expect(error.retry_after).to eq(5.0)
        end
      end
    end

    context 'when the response contains invalid JSON' do
      let(:invalid_json_response) do
        {
          'choices' => [
            {
              'message' => {
                'content' => 'not valid json',
              },
            },
          ],
          'usage' => {
            'prompt_tokens' => 10,
            'completion_tokens' => 5,
            'total_tokens' => 15,
          },
        }
      end

      before do
        stub_request(:post, "#{api_base_url}/chat/completions")
          .to_return(status: 200, body: invalid_json_response.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns the raw string' do
        result = client.call('test')
        expect(result).to eq('not valid json')
      end

      it 'attaches usage metadata to the raw string response' do
        result = client.call('test', event_kind: 'label_generation')

        expect(AiUsage.metadata_from(result).to_h).to include(
          event_kind: 'label_generation',
          input_tokens: 10,
          output_tokens: 5,
          total_tokens: 15,
        )
      end
    end

    context 'when the response has no content' do
      let(:empty_response) do
        {
          'choices' => [
            {
              'message' => {},
            },
          ],
        }
      end

      before do
        stub_request(:post, "#{api_base_url}/chat/completions")
          .to_return(status: 200, body: empty_response.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns an empty string' do
        result = client.call('test')
        expect(result).to eq('')
      end
    end
  end

  describe 'retry behaviour' do
    subject(:client) { described_class.new }

    before { allow(Kernel).to receive(:sleep) }

    context 'when a transient SSL error occurs then succeeds' do
      before do
        call_count = 0
        stub_request(:post, "#{api_base_url}/chat/completions").to_return do
          call_count += 1
          if call_count == 1
            raise Faraday::SSLError, 'SSL_connect returned=1 errno=0 state=error: unexpected eof while reading'
          else
            { status: 200, body: response_body.to_json, headers: { 'Content-Type' => 'application/json' } }
          end
        end
      end

      it 'retries and returns the response' do
        result = client.call('test')
        expect(result).to eq('capital' => 'Paris')
      end
    end

    context 'when SSL errors persist' do
      before do
        stub_request(:post, "#{api_base_url}/chat/completions")
          .to_raise(Faraday::SSLError.new('SSL_connect returned=1 errno=0 state=error: unexpected eof while reading'))
      end

      it 'raises after exhausting retries' do
        expect { client.call('test') }.to raise_error(Faraday::SSLError)
      end
    end

    context 'when a transient HTTP error occurs then succeeds' do
      before do
        call_count = 0
        stub_request(:post, "#{api_base_url}/chat/completions").to_return do
          call_count += 1
          if call_count == 1
            { status: 500, body: { error: 'Server Error' }.to_json, headers: { 'Content-Type' => 'application/json' } }
          else
            { status: 200, body: response_body.to_json, headers: { 'Content-Type' => 'application/json' } }
          end
        end
      end

      it 'retries and returns the response' do
        result = client.call('test')
        expect(result).to eq('capital' => 'Paris')
      end
    end

    context 'when HTTP errors persist' do
      before do
        stub_request(:post, "#{api_base_url}/chat/completions")
          .to_return(status: 500, body: { error: 'Server Error' }.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'raises ApiError after exhausting retries' do
        expect { client.call('test') }.to raise_error(OpenaiClient::ApiError)
      end
    end

    context 'with an operation timeout' do
      let(:connection) { instance_double(Faraday::Connection) }
      let(:response) { instance_double(Faraday::Response, success?: true, body: response_body) }
      let(:operation_state) { { now: 0.0, request_timeouts: [] } }

      before do
        allow(described_class).to receive(:client).and_return(connection)
        allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC) { operation_state[:now] }
        allow(Kernel).to receive(:sleep) { |delay| operation_state[:now] += delay }
      end

      it 'caps the combined transport timeouts to the budget' do
        allow(connection).to receive(:post) do |_path, _body, &configure|
          options = Faraday::RequestOptions.new
          configure.call(instance_double(Faraday::Request, options:))
          operation_state[:request_timeouts] << [options.timeout, options.open_timeout]
          response
        end

        client.call('test', timeout: 5)

        expect(operation_state[:request_timeouts]).to eq([[3.75, 1.25]])
        expect(operation_state[:request_timeouts].first.sum).to eq(5.0)
      end

      it 'retries within the remaining budget' do
        attempts = 0
        allow(connection).to receive(:post) do |_path, _body, &configure|
          attempts += 1
          options = Faraday::RequestOptions.new
          configure.call(instance_double(Faraday::Request, options:))
          operation_state[:request_timeouts] << options.timeout
          raise Faraday::SSLError, 'transient' if attempts == 1

          response
        end

        result = client.call('test', timeout: 5)

        expect(result).to eq('capital' => 'Paris')
        expect(operation_state[:request_timeouts]).to eq([3.75, 2.25])
      end

      it 'stops when retry backoff exhausts the budget' do
        allow(connection).to receive(:post) do |_path, _body, &configure|
          options = Faraday::RequestOptions.new
          configure.call(instance_double(Faraday::Request, options:))
          operation_state[:request_timeouts] << options.timeout
          raise Faraday::SSLError, 'transient'
        end

        expect { client.call('test', timeout: 1) }
          .to raise_error(OpenaiClient::DeadlineExceeded) { |error|
            expect(error.elapsed_seconds).to eq(0.0)
            expect(error.message).to include('1000ms deadline')
          }

        expect(operation_state[:request_timeouts]).to eq([0.75])
        expect(Kernel).not_to have_received(:sleep)
      end

      it 'converts transport expiry into a deadline error' do
        allow(connection).to receive(:post) do |_path, _body, &configure|
          options = Faraday::RequestOptions.new
          configure.call(instance_double(Faraday::Request, options:))
          operation_state[:request_timeouts] << options.timeout
          operation_state[:now] = 5.0
          raise Faraday::TimeoutError, 'execution expired'
        end

        expect { client.call('test', timeout: 5) }
          .to raise_error(OpenaiClient::DeadlineExceeded)

        expect(operation_state[:request_timeouts]).to eq([3.75])
        expect(Kernel).not_to have_received(:sleep)
      end

      it 'rejects a response that completes after the operation deadline' do
        allow(connection).to receive(:post) do |_path, _body, &configure|
          options = Faraday::RequestOptions.new
          configure.call(instance_double(Faraday::Request, options:))
          operation_state[:request_timeouts] << options.timeout
          operation_state[:now] = 5.01
          response
        end

        expect { client.call('test', timeout: 5) }
          .to raise_error(OpenaiClient::DeadlineExceeded) { |error|
            expect(error.elapsed_seconds).to eq(5.01)
          }

        expect(operation_state[:request_timeouts]).to eq([3.75])
      end
    end
  end

  describe '.call' do
    let(:context) { 'What is the capital of France?' }

    before do
      stub_request(:post, "#{api_base_url}/chat/completions")
        .to_return(status: 200, body: response_body.to_json, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns the expected response content' do
      result = described_class.call(context)
      expect(result).to eq('capital' => 'Paris')
    end

    it 'logs the duration of the call' do
      allow(Rails.logger).to receive(:debug).and_call_original
      described_class.call(context)
      expect(Rails.logger).to have_received(:debug).with(/OpenaiClient call took \d+\.\d+ seconds/)
    end
  end

  describe '.client' do
    before do
      described_class.instance_variable_set(:@client, nil)
    end

    after do
      described_class.instance_variable_set(:@client, nil)
    end

    it 'creates a Faraday client with correct configuration' do
      client = described_class.client

      expect(client).to be_a(Faraday::Connection)
      expect(client.headers['Authorization']).to eq("Bearer #{TradeTariffBackend.openai_api_key}")
      expect(client.headers['Content-Type']).to eq('application/json')
      expect(client.headers['User-Agent']).to eq(TradeTariffBackend.user_agent)
    end

    it 'memoizes the client' do
      client1 = described_class.client
      client2 = described_class.client

      expect(client1).to be(client2)
    end
  end
end
