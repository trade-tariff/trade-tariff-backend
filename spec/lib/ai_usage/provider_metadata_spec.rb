RSpec.describe 'AI provider metadata' do
  before do
    allow(Kernel).to receive(:sleep)
    allow(TradeTariffBackend).to receive(:openai_model_pricing).and_return({
      model => { 'input_per_million_tokens' => 2.0, 'output_per_million_tokens' => 8.0 },
    })
  end

  shared_examples 'provider metadata without usage' do
    [nil, {}].each do |usage|
      context "with usage #{usage.inspect}" do
        before do
          stub_request(:post, endpoint).to_return(
            status: 200,
            body: success_body.merge('usage' => usage).to_json,
            headers: { 'Content-Type' => 'application/json', 'x-request-id' => 'req_success' },
          )
        end

        it 'keeps token usage unknown' do
          metadata = AiUsage.metadata_from(call_provider.call)

          expect(metadata.to_h).to include(
            openai_request_id: 'req_success',
            input_tokens: nil,
            total_tokens: nil,
            total_cost_usd: nil,
            pricing_known: false,
          )
        end
      end
    end

    context 'with measured zero usage' do
      before do
        stub_request(:post, endpoint).to_return(
          status: 200,
          body: success_body.merge('usage' => { 'prompt_tokens' => 0, 'completion_tokens' => 0, 'total_tokens' => 0 }).to_json,
          headers: { 'Content-Type' => 'application/json', 'x-request-id' => 'req_zero' },
        )
      end

      it 'preserves observed zero usage' do
        expect(AiUsage.metadata_from(call_provider.call).to_h).to include(
          total_tokens: 0,
          total_cost_usd: 0.0,
          pricing_known: true,
        )
      end
    end

    [400, 500].each do |status|
      context "with a plain-text #{status} response" do
        before do
          stub_request(:post, endpoint).to_return(
            status:,
            body: 'upstream unavailable',
            headers: { 'Content-Type' => 'text/plain', 'x-request-id' => 'req_failure' },
          )
        end

        it 'retains the request id in the failed event' do
          events = []
          collector = ->(_name, _start, _finish, _id, payload) { events << payload }

          ActiveSupport::Notifications.subscribed(collector, 'api_call_failed.ai_usage') do
            expect {
              AiUsage::Instrumentation.api_call(event_kind: 'metadata_test', model:) { call_provider.call }
            }.to raise_error(error_class)
          end

          expect(events.size).to eq(1)
          expect(events.first).to include(openai_request_id: 'req_failure', pricing_known: false)
          expect(events.first).not_to have_key(:total_tokens)
        end
      end
    end
  end

  context 'with Chat Completions' do
    let(:model) { 'gpt-test' }
    let(:endpoint) { 'https://gb.api.openai.com/v1/chat/completions' }
    let(:success_body) { { 'choices' => [{ 'message' => { 'content' => '{"answer":"test"}' } }] } }
    let(:error_class) { OpenaiClient::ApiError }
    let(:call_provider) { -> { OpenaiClient.new.call('test', model:, event_kind: 'metadata_test') } }

    include_examples 'provider metadata without usage'
  end

  context 'with embeddings' do
    let(:model) { EmbeddingService::MODEL }
    let(:endpoint) { 'https://gb.api.openai.com/v1/embeddings' }
    let(:success_body) { { 'data' => [{ 'index' => 0, 'embedding' => Array.new(1536, 0.1) }] } }
    let(:error_class) { EmbeddingService::ApiError }
    let(:call_provider) { -> { EmbeddingService.new.embed('test', event_kind: 'metadata_test') } }

    before { EmbeddingService.reset_client! }

    include_examples 'provider metadata without usage'
  end
end
