RSpec.describe LabelGenerator::Instrumentation do
  describe '.api_call' do
    it 'emits label generation event kind and AI usage metadata' do
      events = []
      subscriber = ActiveSupport::Notifications.subscribe('api_call_completed.label_generator') do |*args|
        events << ActiveSupport::Notifications::Event.new(*args)
      end

      response = AiUsage.attach_metadata(
        { 'data' => [{ 'commodity_code' => '0101210000' }] },
        AiUsage::Metadata.new(
          provider: 'openai',
          model: 'gpt-5.2',
          event_kind: 'label_generation',
          input_tokens: 100,
          cached_input_tokens: nil,
          output_tokens: 50,
          total_tokens: 150,
          input_cost_usd: nil,
          cached_input_cost_usd: nil,
          output_cost_usd: nil,
          total_cost_usd: nil,
          pricing_known: false,
        ),
      )

      described_class.api_call(batch_size: 1, model: 'gpt-5.2', page_number: 2) { response }

      expect(events.size).to eq(1)
      expect(events.first.payload).to include(
        event_kind: 'label_generation',
        input_tokens: 100,
        output_tokens: 50,
        total_tokens: 150,
        pricing_known: false,
      )
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    end

    it 'redacts OpenAI provider response bodies from failure instrumentation' do
      events = []
      subscriber = ActiveSupport::Notifications.subscribe('api_call_failed.label_generator') do |*args|
        events << ActiveSupport::Notifications::Event.new(*args)
      end

      error = OpenaiClient::ApiError.new(status: 500, body: { prompt: 'do not log this' })

      expect {
        described_class.api_call(batch_size: 1, model: 'gpt-5.2', page_number: 2) { raise error }
      }.to raise_error(OpenaiClient::ApiError)

      expect(events.size).to eq(1)
      expect(events.first.payload).to include(
        error_class: 'OpenaiClient::ApiError',
        error_message: 'OpenAI API error status=500',
      )
      expect(events.first.payload[:error_message]).not_to include('do not log this')
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    end
  end

  describe '.embedding_api_call' do
    it 'emits label scoring embedding event kind and AI usage metadata' do
      events = []
      subscriber = ActiveSupport::Notifications.subscribe('embedding_api_call_completed.label_generator') do |*args|
        events << ActiveSupport::Notifications::Event.new(*args)
      end

      embeddings = AiUsage.attach_metadata(
        [[0.1, 0.2]],
        AiUsage::Metadata.new(
          provider: 'openai',
          model: 'text-embedding-3-small',
          event_kind: 'label_scoring_embedding',
          input_tokens: 20,
          cached_input_tokens: nil,
          output_tokens: 0,
          total_tokens: 20,
          input_cost_usd: 0.0000004,
          cached_input_cost_usd: nil,
          output_cost_usd: nil,
          total_cost_usd: 0.0000004,
          pricing_known: true,
        ),
      )

      described_class.embedding_api_call(batch_size: 1, model: 'text-embedding-3-small') { embeddings }

      expect(events.size).to eq(1)
      expect(events.first.payload).to include(
        event_kind: 'label_scoring_embedding',
        input_tokens: 20,
        output_tokens: 0,
        total_tokens: 20,
        total_cost_usd: 0.0000004,
        pricing_known: true,
      )
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    end
  end
end
