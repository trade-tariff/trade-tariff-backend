RSpec.describe OpenaiTransport do
  let(:responses_url) { 'https://gb.api.openai.com/v1/responses' }
  let(:events) { [] }
  let(:response_body) do
    {
      'status' => 'completed',
      'model' => 'gpt-5.2',
      'output' => [{ 'type' => 'message', 'content' => [{ 'type' => 'output_text', 'text' => '{"ok":true}' }] }],
      'usage' => { 'input_tokens' => 10, 'output_tokens' => 2, 'total_tokens' => 12 },
    }
  end

  around do |example|
    subscriber = ActiveSupport::Notifications.subscribe(/\.ruby_llm\z/) do |event|
      events << [event.name, event.payload.slice(:provider, :status, :operation)]
    end
    example.run
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  it 'passes RubyLLM events to ActiveSupport::Notifications' do
    stub_request(:post, responses_url)
      .to_return(status: 200, body: response_body.to_json, headers: { 'Content-Type' => 'application/json' })

    OpenaiClient.call('test')

    expect(events).to include(
      ['request.ruby_llm', a_hash_including(provider: 'openai', status: 200)],
      ['usage.ruby_llm', a_hash_including(provider: 'openai', operation: :chat, status: :succeeded)],
      ['chat.ruby_llm', a_hash_including(provider: 'openai')],
    )
  end

  it 'leaves retries to the caller' do
    stub_request(:post, responses_url).to_return(status: 503, body: '', headers: {})

    response = described_class.request do |llm|
      llm.chat(model: 'gpt-5.2', provider: :openai, assume_model_exists: true).ask('test')
    end

    expect(response.status).to eq(503)
    expect(WebMock).to have_requested(:post, responses_url).once
  end

  context 'without an API key' do
    before do
      allow(TradeTariffBackend).to receive(:openai_api_key).and_return(nil)
      allow(Kernel).to receive(:sleep)
      stub_request(:post, %r{\Ahttps://gb\.api\.openai\.com/v1/})
        .to_return(status: 401, body: { error: { message: 'Missing bearer' } }.to_json, headers: { 'Content-Type' => 'application/json' })
    end

    it 'sends chat requests that the provider rejects, as before' do
      expect { OpenaiClient.call('test') }
        .to raise_error(OpenaiClient::ApiError) { |error| expect(error.status).to eq(401) }

      expect(a_request(:post, responses_url).with { |request| request.headers['Authorization'].strip == 'Bearer' })
        .to have_been_made.times(OpenaiClient::MAX_RETRIES)
    end

    it 'sends embedding requests that the provider rejects, as before' do
      expect { EmbeddingService.new.embed('test') }
        .to raise_error(EmbeddingService::ClientError) { |error| expect(error.http_status).to eq(401) }

      expect(a_request(:post, 'https://gb.api.openai.com/v1/embeddings').with { |request| request.headers['Authorization'].strip == 'Bearer' })
        .to have_been_made.once
    end
  end
end
