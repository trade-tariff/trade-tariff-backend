RSpec.describe AiUsage::Instrumentation do
  describe '.api_call' do
    it 'redacts provider response bodies from failure instrumentation' do
      events = []
      subscriber = ActiveSupport::Notifications.subscribe('api_call_failed.ai_usage') do |*args|
        events << ActiveSupport::Notifications::Event.new(*args)
      end

      error = OpenaiClient::ApiError.new(status: 500, body: { prompt: 'do not log this' })

      expect {
        described_class.api_call(event_kind: 'atar_fact_extraction', model: 'gpt-test') { raise error }
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
end
