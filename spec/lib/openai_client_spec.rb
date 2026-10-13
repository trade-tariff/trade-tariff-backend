RSpec.describe OpenaiClient do
  let(:api_base_url) { 'https://gb.api.openai.com/v1' }
  let(:response_body) do
    {
      'status' => 'completed',
      'output' => [
        { 'type' => 'reasoning', 'summary' => [] },
        {
          'type' => 'message',
          'content' => [
            { 'type' => 'output_text', 'text' => '{"capital":"Paris"}' },
          ],
        },
      ],
      'usage' => {
        'input_tokens' => 1_000,
        'output_tokens' => 250,
        'total_tokens' => 1_250,
      },
    }
  end

  describe '#call' do
    subject(:client) { described_class.new }

    context 'when given a string context' do
      let(:context) { 'What is the capital of France?' }

      before do
        stub_request(:post, "#{api_base_url}/responses")
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

        expect(WebMock).to have_requested(:post, "#{api_base_url}/responses")
          .with(body: hash_including(
            'input' => [{ 'role' => 'user', 'content' => context }],
          ))
      end

      it 'requests JSON output without storing the response' do
        client.call(context)

        expect(WebMock).to have_requested(:post, "#{api_base_url}/responses")
          .with(body: hash_including(
            'model' => TradeTariffBackend.ai_model,
            'safety_identifier' => TradeTariffBackend.openai_user,
            'text' => { 'format' => { 'type' => 'json_object' } },
            'store' => false,
          ))
      end
    end

    context 'when the provider returns response metadata' do
      let(:context) { 'What is the capital of France?' }
      let(:response_body) do
        {
          'id' => 'resp_body_id',
          'model' => 'gpt-5.4-2025-01-01',
          'service_tier' => 'default',
          'status' => 'completed',
          'output' => [
            {
              'type' => 'message',
              'content' => [{ 'type' => 'output_text', 'text' => '{"capital":"Paris"}' }],
            },
          ],
          'usage' => {
            'input_tokens' => 1_000,
            'input_tokens_details' => { 'cached_tokens' => 600 },
            'output_tokens' => 250,
            'output_tokens_details' => { 'reasoning_tokens' => 180 },
            'total_tokens' => 1_250,
          },
        }
      end

      before do
        stub_request(:post, "#{api_base_url}/responses")
          .to_return(
            status: 200,
            body: response_body.to_json,
            headers: {
              'Content-Type' => 'application/json',
              'x-request-id' => 'req_openai_header',
            },
          )
      end

      it 'attaches served model and finish reason' do
        result = client.call(context, event_kind: 'search_query_expansion', reasoning_effort: 'medium')

        expect(AiUsage.metadata_from(result).to_h).to include(
          served_model: 'gpt-5.4-2025-01-01',
          finish_reason: 'completed',
          service_tier: 'default',
          reasoning_effort: 'medium',
          cached_input_tokens: 600,
          reasoning_tokens: 180,
          openai_request_id: 'req_openai_header',
          openai_response_id: 'resp_body_id',
        )
      end
    end

    context 'when the response is incomplete' do
      let(:response_body) do
        {
          'status' => 'incomplete',
          'incomplete_details' => { 'reason' => 'max_output_tokens' },
          'output' => [
            { 'type' => 'message', 'content' => [{ 'type' => 'output_text', 'text' => '{"capital":"Par"}' }] },
          ],
          'usage' => { 'input_tokens' => 1_000, 'output_tokens' => 4_000, 'total_tokens' => 5_000 },
        }
      end

      before do
        allow(Kernel).to receive(:sleep)
        stub_request(:post, "#{api_base_url}/responses")
          .to_return(status: 200, body: response_body.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'raises ResponseIncompleteError instead of returning the partial JSON' do
        expect { client.call('test', model: 'gpt-test', event_kind: 'interactive_search') }
          .to raise_error(OpenaiClient::ResponseIncompleteError) { |error|
            expect(error.message).to eq('OpenAI response status=incomplete reason=max_output_tokens')
            expect(error.ai_usage.to_h).to include(
              model: 'gpt-test',
              event_kind: 'interactive_search',
              finish_reason: 'max_output_tokens',
              input_tokens: 1_000,
              output_tokens: 4_000,
            )
          }
      end

      it 'does not retry' do
        expect { client.call('test') }.to raise_error(OpenaiClient::ResponseIncompleteError)

        expect(WebMock).to have_requested(:post, "#{api_base_url}/responses").once
        expect(Kernel).not_to have_received(:sleep)
      end

      it 'records a failed AI usage event with the usage and reason' do
        events = []
        collector = ->(_name, _start, _finish, _id, payload) { events << payload }

        ActiveSupport::Notifications.subscribed(collector, 'api_call_failed.ai_usage') do
          expect {
            AiUsage::Instrumentation.api_call(event_kind: 'label_generation', model: 'gpt-test') do
              client.call('test', model: 'gpt-test', event_kind: 'label_generation')
            end
          }.to raise_error(OpenaiClient::ResponseIncompleteError)
        end

        expect(events.sole).to include(
          error_class: 'OpenaiClient::ResponseIncompleteError',
          error_message: 'OpenAI response status=incomplete reason=max_output_tokens',
          finish_reason: 'max_output_tokens',
          input_tokens: 1_000,
          output_tokens: 4_000,
        )
      end
    end

    context 'when the response failed' do
      let(:failed_body) do
        {
          'status' => 'failed',
          'error' => { 'code' => 'server_error', 'message' => 'The model failed.' },
          'output' => [],
          'usage' => { 'input_tokens' => 1_000, 'output_tokens' => 0, 'total_tokens' => 1_000 },
        }
      end

      before { allow(Kernel).to receive(:sleep) }

      it 'retries and returns the completed response with the usage of both attempts' do
        allow(TradeTariffBackend).to receive(:openai_model_pricing).and_return({
          'gpt-test' => { 'input_per_million_tokens' => 2.0, 'output_per_million_tokens' => 8.0 },
        })
        stub_request(:post, "#{api_base_url}/responses")
          .to_return(
            { status: 200, body: failed_body.to_json, headers: { 'Content-Type' => 'application/json' } },
            { status: 200, body: response_body.to_json, headers: { 'Content-Type' => 'application/json' } },
          )

        result = client.call('test', model: 'gpt-test')

        expect(result).to eq('capital' => 'Paris')
        expect(Kernel).to have_received(:sleep).with(2).once
        expect(AiUsage.metadata_from(result).to_h).to include(
          input_tokens: 2_000,
          output_tokens: 250,
          total_tokens: 2_250,
          total_cost_usd: 0.006,
          pricing_known: true,
          finish_reason: 'completed',
        )
      end

      it 'adds the failed attempt usage to a later incomplete response' do
        incomplete_body = {
          'status' => 'incomplete',
          'incomplete_details' => { 'reason' => 'max_output_tokens' },
          'output' => [],
          'usage' => { 'input_tokens' => 1_000, 'output_tokens' => 4_000, 'total_tokens' => 5_000 },
        }
        stub_request(:post, "#{api_base_url}/responses")
          .to_return(
            { status: 200, body: failed_body.to_json, headers: { 'Content-Type' => 'application/json' } },
            { status: 200, body: incomplete_body.to_json, headers: { 'Content-Type' => 'application/json' } },
          )

        expect { client.call('test') }
          .to raise_error(OpenaiClient::ResponseIncompleteError) { |error|
            expect(error.ai_usage.to_h).to include(
              input_tokens: 2_000,
              output_tokens: 4_000,
              finish_reason: 'max_output_tokens',
            )
          }
      end

      it 'adds the failed attempt usage to a deadline error' do
        allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(0.0, 0.5, 0.5)
        stub_request(:post, "#{api_base_url}/responses")
          .to_return(status: 200, body: failed_body.to_json, headers: { 'Content-Type' => 'application/json' })

        expect { client.call('test', timeout: 1) }
          .to raise_error(OpenaiClient::DeadlineExceeded) { |error|
            expect(error.ai_usage.to_h).to include(input_tokens: 1_000, finish_reason: 'server_error')
          }
      end

      it 'does not mark pricing unknown for an earlier attempt without usage' do
        allow(TradeTariffBackend).to receive(:openai_model_pricing).and_return({
          'gpt-test' => { 'input_per_million_tokens' => 2.0, 'output_per_million_tokens' => 8.0 },
        })
        stub_request(:post, "#{api_base_url}/responses")
          .to_return(
            { status: 500, body: { error: 'Server Error' }.to_json, headers: { 'Content-Type' => 'application/json' } },
            { status: 200, body: response_body.to_json, headers: { 'Content-Type' => 'application/json' } },
          )

        result = client.call('test', model: 'gpt-test')

        expect(AiUsage.metadata_from(result).to_h).to include(input_tokens: 1_000, pricing_known: true)
      end

      it 'raises ResponseFailedError with usage after exhausting retries' do
        stub_request(:post, "#{api_base_url}/responses")
          .to_return(status: 200, body: failed_body.to_json, headers: { 'Content-Type' => 'application/json' })

        expect { client.call('test', model: 'gpt-test', event_kind: 'interactive_search') }
          .to raise_error(OpenaiClient::ResponseFailedError) { |error|
            expect(error).to be_a(OpenaiClient::ApiError)
            expect(error.message).to eq('OpenAI response status=failed reason=server_error')
            expect(error.ai_usage.to_h).to include(finish_reason: 'server_error', input_tokens: 3_000)
          }

        expect(WebMock).to have_requested(:post, "#{api_base_url}/responses").times(3)
      end
    end

    context 'when the response has no status' do
      let(:malformed_body) do
        {
          'output' => [
            { 'type' => 'message', 'content' => [{ 'type' => 'output_text', 'text' => '{"capital":"Paris"}' }] },
          ],
          'usage' => { 'input_tokens' => 10, 'output_tokens' => 5, 'total_tokens' => 15 },
        }
      end

      before do
        allow(Kernel).to receive(:sleep)
        stub_request(:post, "#{api_base_url}/responses")
          .to_return(status: 200, body: malformed_body.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'raises ResponseFailedError instead of returning the output' do
        expect { client.call('test') }
          .to raise_error(OpenaiClient::ResponseFailedError) { |error|
            expect(error.response_status).to be_nil
            expect(error.message).to eq('OpenAI response status=missing')
          }

        expect(WebMock).to have_requested(:post, "#{api_base_url}/responses").times(3)
      end
    end

    context 'when only a response id is present' do
      let(:context) { 'What is the capital of France?' }
      let(:response_body) do
        {
          'id' => 'resp_body_id',
          'status' => 'completed',
          'output' => [
            { 'type' => 'message', 'content' => [{ 'type' => 'output_text', 'text' => '{"capital":"Paris"}' }] },
          ],
          'usage' => {
            'input_tokens' => 1_000,
            'output_tokens' => 250,
            'total_tokens' => 1_250,
          },
        }
      end

      before do
        stub_request(:post, "#{api_base_url}/responses")
          .to_return(status: 200, body: response_body.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'records the response id separately from the request id' do
        result = client.call(context)
        metadata = AiUsage.metadata_from(result)

        expect(metadata.openai_response_id).to eq('resp_body_id')
        expect(metadata.openai_request_id).to be_nil
      end
    end

    context 'when given a reasoning_effort parameter' do
      let(:context) { 'What is the capital of France?' }

      before do
        stub_request(:post, "#{api_base_url}/responses")
          .to_return(status: 200, body: response_body.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'includes the reasoning effort in the request body when present' do
        client.call(context, reasoning_effort: 'low')

        expect(WebMock).to have_requested(:post, "#{api_base_url}/responses")
          .with(body: hash_including('reasoning' => { 'effort' => 'low' }))
      end

      it 'omits the reasoning effort from the request body when nil' do
        client.call(context)

        expect(WebMock).to(have_requested(:post, "#{api_base_url}/responses")
          .with { |req| !JSON.parse(req.body).key?('reasoning') })
      end

      it 'omits the reasoning effort from the request body when blank' do
        client.call(context, reasoning_effort: '')

        expect(WebMock).to(have_requested(:post, "#{api_base_url}/responses")
          .with { |req| !JSON.parse(req.body).key?('reasoning') })
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
        stub_request(:post, "#{api_base_url}/responses")
          .to_return(status: 200, body: response_body.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'sends the messages array directly' do
        client.call(messages)

        expect(WebMock).to have_requested(:post, "#{api_base_url}/responses")
          .with(body: hash_including('input' => messages))
      end
    end

    context 'when the API returns a 500 error response' do
      let(:error_body) do
        {
          error: 'Internal Server Error',
          usage: {
            input_tokens: 20,
            output_tokens: 0,
            total_tokens: 20,
          },
        }
      end

      before do
        allow(Kernel).to receive(:sleep)

        stub_request(:post, "#{api_base_url}/responses")
          .to_return(status: 500, body: error_body.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'raises an ApiError' do
        expect { client.call('test') }.to raise_error(OpenaiClient::ApiError) do |error|
          expect(error.status).to eq(500)
          expect(error.message).to eq('OpenAI API error status=500')
          expect(error.message).not_to include('Internal Server Error')
          expect(error.body['error']).to eq('Internal Server Error')
          expect(error.body.dig('usage', 'input_tokens')).to eq(20)
        end
      end

      it 'attaches the usage of every attempt to ApiError when the provider returns usage' do
        expect { client.call('test', model: 'gpt-test', event_kind: 'interactive_search') }
          .to raise_error(OpenaiClient::ApiError) { |error|
            expect(error.ai_usage.to_h).to include(
              model: 'gpt-test',
              event_kind: 'interactive_search',
              input_tokens: 60,
              total_tokens: 60,
            )
          }
      end
    end

    context 'when the API returns a 429 rate limit response' do
      before do
        allow(Kernel).to receive(:sleep)

        stub_request(:post, "#{api_base_url}/responses")
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
          'status' => 'completed',
          'output' => [
            { 'type' => 'message', 'content' => [{ 'type' => 'output_text', 'text' => 'not valid json' }] },
          ],
          'usage' => {
            'input_tokens' => 10,
            'output_tokens' => 5,
            'total_tokens' => 15,
          },
        }
      end

      before do
        stub_request(:post, "#{api_base_url}/responses")
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
          'status' => 'completed',
          'output' => [
            { 'type' => 'message', 'content' => [] },
          ],
        }
      end

      before do
        stub_request(:post, "#{api_base_url}/responses")
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
        stub_request(:post, "#{api_base_url}/responses").to_return do
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
        stub_request(:post, "#{api_base_url}/responses")
          .to_raise(Faraday::SSLError.new('SSL_connect returned=1 errno=0 state=error: unexpected eof while reading'))
      end

      it 'raises after exhausting retries' do
        expect { client.call('test') }.to raise_error(Faraday::SSLError)
      end
    end

    context 'when a transient HTTP error occurs then succeeds' do
      before do
        call_count = 0
        stub_request(:post, "#{api_base_url}/responses").to_return do
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
        expect(Kernel).to have_received(:sleep).with(2).once
      end
    end

    context 'when HTTP errors persist' do
      before do
        stub_request(:post, "#{api_base_url}/responses")
          .to_return(status: 500, body: { error: 'Server Error' }.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'raises ApiError after exhausting retries' do
        expect { client.call('test') }.to raise_error(OpenaiClient::ApiError)
        expect(WebMock).to have_requested(:post, "#{api_base_url}/responses").times(3)
        expect(Kernel).to have_received(:sleep).with(2).once
        expect(Kernel).to have_received(:sleep).with(4).once
      end
    end

    context 'when rate-limited and then successful' do
      before do
        stub_request(:post, "#{api_base_url}/responses")
          .to_return(
            { status: 429, body: { error: 'Rate limit exceeded' }.to_json, headers: { 'Content-Type' => 'application/json', 'Retry-After' => '5' } },
            { status: 200, body: response_body.to_json, headers: { 'Content-Type' => 'application/json' } },
          )
      end

      it 'uses Retry-After delay for retry' do
        result = client.call('test')
        expect(result).to eq('capital' => 'Paris')
        expect(Kernel).to have_received(:sleep).with(5.0).once
      end
    end

    context 'when Retry-After exceeds the remaining operation timeout' do
      before do
        stub_request(:post, "#{api_base_url}/responses")
          .to_return(status: 429, body: { error: 'Rate limit exceeded' }.to_json, headers: { 'Content-Type' => 'application/json', 'Retry-After' => '5' })
      end

      it 'raises DeadlineExceeded without sleeping or retrying' do
        expect { client.call('test', timeout: 1) }
          .to raise_error(OpenaiClient::DeadlineExceeded)

        expect(Kernel).not_to have_received(:sleep)
        expect(WebMock).to have_requested(:post, "#{api_base_url}/responses").once
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

      it 'raises DeadlineExceeded before the first request when the deadline has already elapsed' do
        allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(0.0, 1.01)
        allow(connection).to receive(:post).and_return(response)

        expect { client.call('test', timeout: 1) }
          .to raise_error(OpenaiClient::DeadlineExceeded)

        expect(connection).not_to have_received(:post)
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

      it 'raises DeadlineExceeded on final failure when the deadline has elapsed' do
        attempts = 0
        allow(connection).to receive(:post) do |_path, _body, &configure|
          attempts += 1
          options = Faraday::RequestOptions.new
          configure.call(instance_double(Faraday::Request, options:))
          operation_state[:request_timeouts] << options.timeout
          operation_state[:now] = 11.0 if attempts == 3
          raise Faraday::SSLError, 'transient'
        end

        expect { client.call('test', timeout: 10) }
          .to raise_error(OpenaiClient::DeadlineExceeded)

        expect(operation_state[:request_timeouts]).to eq([7.5, 6.0, 3.0])
        expect(Kernel).to have_received(:sleep).with(2).once
        expect(Kernel).to have_received(:sleep).with(4).once
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
      stub_request(:post, "#{api_base_url}/responses")
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
