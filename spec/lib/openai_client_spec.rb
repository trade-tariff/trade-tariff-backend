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

      it 'sends the context as a user message' do
        client.call(context)

        expect(WebMock).to have_requested(:post, "#{api_base_url}/chat/completions")
          .with(body: hash_including(
            'messages' => [{ 'role' => 'user', 'content' => context }],
          ))
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

    context 'when the API returns an error response' do
      before do
        stub_request(:post, "#{api_base_url}/chat/completions")
          .to_return(status: 500, body: { error: 'Internal Server Error' }.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns an empty string' do
        result = client.call('test')
        expect(result).to eq('')
      end

      it 'logs the error' do
        allow(Rails.logger).to receive(:error)
        client.call('test')
        expect(Rails.logger).to have_received(:error).with(/OpenAIClient error/)
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
    it 'creates a Faraday client with correct configuration' do
      client = described_class.client

      expect(client).to be_a(Faraday::Connection)
      expect(client.headers['Authorization']).to eq('Bearer test-api-key')
      expect(client.headers['Content-Type']).to eq('application/json')
      expect(client.headers['User-Agent']).to eq('TradeTariffBackend/')
    end

    it 'memoizes the client' do
      client1 = described_class.client
      client2 = described_class.client

      expect(client1).to be(client2)
    end
  end
end
