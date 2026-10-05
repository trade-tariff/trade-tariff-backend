RSpec.describe BedrockOpenaiClient do
  let(:api_base_url) { 'https://bedrock-runtime.eu-west-2.amazonaws.com/openai/v1' }
  let(:bedrock_model) { 'global.openai.gpt-5.6-terra' }
  let(:response_body) do
    {
      'choices' => [{ 'message' => { 'content' => '{"capital":"Paris"}' } }],
      'usage' => { 'prompt_tokens' => 1_000, 'completion_tokens' => 250, 'total_tokens' => 1_250 },
    }
  end

  before do
    described_class.instance_variable_set(:@client, nil)
    allow(TradeTariffBackend).to receive_messages(
      bedrock_api_base_url: api_base_url,
      bedrock_api_key: 'bedrock-test-key',
      bedrock_search_model: bedrock_model,
    )
    stub_request(:post, "#{api_base_url}/chat/completions")
      .to_return(status: 200, body: response_body.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  after do
    described_class.instance_variable_set(:@client, nil)
  end

  describe '.call' do
    it 'returns the parsed JSON response' do
      expect(described_class.call('What is the capital of France?')).to eq('capital' => 'Paris')
    end

    it 'sends the request to Bedrock with the Bedrock API key' do
      described_class.call('What is the capital of France?')

      expect(WebMock).to have_requested(:post, "#{api_base_url}/chat/completions")
        .with(headers: { 'Authorization' => 'Bearer bedrock-test-key' })
    end

    it 'uses the Bedrock ID of the configured model when Bedrock serves it' do
      described_class.call('What is the capital of France?', model: 'gpt-5.6-luna', reasoning_effort: 'low')

      expect(WebMock).to have_requested(:post, "#{api_base_url}/chat/completions")
        .with(body: hash_including('model' => 'global.openai.gpt-5.6-luna', 'reasoning_effort' => 'low'))
    end

    it 'falls back to the Bedrock search model when Bedrock does not serve the configured model' do
      described_class.call('What is the capital of France?', model: 'gpt-5.2', reasoning_effort: 'low')

      expect(WebMock).to have_requested(:post, "#{api_base_url}/chat/completions")
        .with(body: hash_including('model' => bedrock_model, 'reasoning_effort' => 'low'))
    end

    it 'falls back to the Bedrock search model when no model is given' do
      described_class.call('What is the capital of France?')

      expect(WebMock).to have_requested(:post, "#{api_base_url}/chat/completions")
        .with(body: hash_including('model' => bedrock_model))
    end

    it 'prices usage against the Bedrock model' do
      result = described_class.call('What is the capital of France?', event_kind: 'interactive_search')

      expect(AiUsage.metadata_from(result).to_h).to include(
        model: bedrock_model,
        event_kind: 'interactive_search',
        total_cost_usd: 0.005,
        pricing_known: true,
      )
    end
  end

  describe '.client' do
    it 'does not share the OpenAI connection' do
      expect(described_class.client.url_prefix.to_s).to eq(api_base_url)
      expect(described_class.client).not_to be(OpenaiClient.client)
    end
  end
end
