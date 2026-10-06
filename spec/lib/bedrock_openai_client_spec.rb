RSpec.describe BedrockOpenaiClient do
  let(:api_base_url) { 'https://bedrock-runtime.eu-west-2.amazonaws.com/openai/v1' }
  let(:responses_url) { "#{api_base_url}/responses" }
  let(:response_body) do
    {
      'id' => 'resp_123',
      'model' => 'global.openai.gpt-5.6-terra',
      'status' => 'completed',
      'output' => [
        { 'type' => 'reasoning', 'summary' => [] },
        { 'type' => 'message', 'content' => [{ 'type' => 'output_text', 'text' => '{"capital":"Paris"}' }] },
      ],
      'usage' => {
        'input_tokens' => 2_000,
        'input_tokens_details' => { 'cached_tokens' => 1_500 },
        'output_tokens' => 250,
        'output_tokens_details' => { 'reasoning_tokens' => 100 },
        'total_tokens' => 2_250,
      },
    }
  end

  before do
    described_class.instance_variable_set(:@client, nil)
    allow(TradeTariffBackend).to receive_messages(
      bedrock_api_base_url: api_base_url,
      bedrock_api_key: 'bedrock-test-key',
    )
    stub_request(:post, responses_url)
      .to_return(status: 200, body: response_body.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  after do
    described_class.instance_variable_set(:@client, nil)
  end

  describe '.bedrock_model?' do
    it 'is true for a Bedrock model key' do
      expect(described_class.bedrock_model?('bedrock/gpt-5.6-luna')).to be(true)
    end

    it 'is false for an OpenAI model' do
      expect(described_class.bedrock_model?('gpt-5.6-luna')).to be(false)
    end
  end

  describe '.call' do
    let(:messages) { [{ role: 'user', content: 'What is the capital of France? Reply in JSON.' }] }

    it 'returns the parsed JSON from the output_text items' do
      expect(described_class.call(messages, model: 'bedrock/gpt-5.6-terra')).to eq('capital' => 'Paris')
    end

    it 'sends a Responses API request to Bedrock with the Bedrock API key' do
      described_class.call(messages, model: 'bedrock/gpt-5.6-terra', reasoning_effort: 'medium')

      expect(WebMock).to have_requested(:post, responses_url)
        .with(
          headers: { 'Authorization' => 'Bearer bedrock-test-key' },
          body: {
            'model' => 'global.openai.gpt-5.6-terra',
            'input' => [{ 'role' => 'user', 'content' => 'What is the capital of France? Reply in JSON.' }],
            'safety_identifier' => TradeTariffBackend.openai_user,
            'text' => { 'format' => { 'type' => 'json_object' } },
            'reasoning' => { 'effort' => 'medium' },
          },
        )
    end

    it 'omits reasoning when no reasoning effort is given' do
      described_class.call(messages, model: 'bedrock/gpt-5.6-luna')

      expect(WebMock).to(have_requested(:post, responses_url).with { |request| !JSON.parse(request.body).key?('reasoning') })
    end

    it 'maps each Bedrock model key to its global inference profile' do
      described_class.call(messages, model: 'bedrock/gpt-5.6-luna')

      expect(WebMock).to have_requested(:post, responses_url)
        .with(body: hash_including('model' => 'global.openai.gpt-5.6-luna'))
    end

    it 'raises for a model that is not a Bedrock model key' do
      expect { described_class.call(messages, model: 'gpt-5.2') }
        .to raise_error(BedrockOpenaiClient::UnknownModelError, /gpt-5.2/)
    end

    it 'prices usage, including cached tokens, against the Bedrock model' do
      result = described_class.call(messages, model: 'bedrock/gpt-5.6-terra', event_kind: 'interactive_search')

      # Terra: 500 uncached x $2.00 + 1,500 cached x $0.20 + 250 output x $12.00, per 1M tokens.
      expect(AiUsage.metadata_from(result).to_h).to include(
        model: 'global.openai.gpt-5.6-terra',
        event_kind: 'interactive_search',
        input_tokens: 2_000,
        cached_input_tokens: 1_500,
        output_tokens: 250,
        reasoning_tokens: 100,
        finish_reason: 'completed',
        served_model: 'global.openai.gpt-5.6-terra',
        pricing_known: true,
      )
      expect(AiUsage.metadata_from(result).total_cost_usd).to be_within(1e-9).of(0.0043)
    end
  end

  describe '.client' do
    it 'does not share the OpenAI connection' do
      expect(described_class.client.url_prefix.to_s).to eq(api_base_url)
      expect(described_class.client).not_to be(OpenaiClient.client)
    end
  end
end
