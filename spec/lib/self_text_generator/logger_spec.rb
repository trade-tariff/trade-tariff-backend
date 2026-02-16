RSpec.describe SelfTextGenerator::Logger do
  let(:log_subscriber) { described_class.new }

  def build_event(event_name, payload: {}, duration: 0.0)
    ActiveSupport::Notifications::Event.new(
      "#{event_name}.self_text_generator",
      Time.current - (duration / 1000.0),
      Time.current,
      SecureRandom.hex(5),
      payload,
    )
  end

  describe '#generation_started' do
    it 'logs a JSON entry with total_chapters' do
      allow(log_subscriber).to receive(:info)

      log_subscriber.generation_started(build_event('generation_started', payload: { total_chapters: 98 }))

      expect(log_subscriber).to have_received(:info) do |json|
        entry = JSON.parse(json)
        expect(entry).to include(
          'service' => 'self_text_generator',
          'event' => 'generation_started',
          'total_chapters' => 98,
        )
      end
    end
  end

  describe '#generation_completed' do
    it 'logs a JSON entry' do
      allow(log_subscriber).to receive(:info)

      log_subscriber.generation_completed(build_event('generation_completed'))

      expect(log_subscriber).to have_received(:info) do |json|
        entry = JSON.parse(json)
        expect(entry).to include('service' => 'self_text_generator', 'event' => 'generation_completed')
      end
    end
  end

  describe '#chapter_started' do
    it 'logs chapter details' do
      allow(log_subscriber).to receive(:debug)

      log_subscriber.chapter_started(build_event('chapter_started', payload: { chapter_sid: 123, chapter_code: '01' }))

      expect(log_subscriber).to have_received(:debug) do |json|
        entry = JSON.parse(json)
        expect(entry).to include('chapter_sid' => 123, 'chapter_code' => '01')
      end
    end
  end

  describe '#chapter_completed' do
    it 'logs chapter details with duration' do
      allow(log_subscriber).to receive(:info)

      log_subscriber.chapter_completed(build_event(
                                         'chapter_completed',
                                         payload: { chapter_sid: 123, chapter_code: '01', mechanical: { processed: 5 }, ai: { processed: 2 } },
                                         duration: 5000.0,
                                       ))

      expect(log_subscriber).to have_received(:info) do |json|
        entry = JSON.parse(json)
        expect(entry).to include('chapter_sid' => 123, 'chapter_code' => '01')
        expect(entry['duration_ms']).to be_a(Float)
      end
    end
  end

  describe '#chapter_failed' do
    it 'logs error details' do
      allow(log_subscriber).to receive(:error)

      log_subscriber.chapter_failed(build_event('chapter_failed', payload: { chapter_sid: 123, chapter_code: '01', error_class: 'StandardError', error_message: 'boom' }))

      expect(log_subscriber).to have_received(:error) do |json|
        entry = JSON.parse(json)
        expect(entry).to include('error_class' => 'StandardError', 'error_message' => 'boom')
      end
    end
  end

  describe '#api_call_started' do
    it 'logs batch details' do
      allow(log_subscriber).to receive(:debug)

      log_subscriber.api_call_started(build_event('api_call_started', payload: { batch_size: 5, model: 'gpt-4', chapter_code: '01' }))

      expect(log_subscriber).to have_received(:debug) do |json|
        entry = JSON.parse(json)
        expect(entry).to include('batch_size' => 5, 'model' => 'gpt-4', 'chapter_code' => '01')
      end
    end
  end

  describe '#api_call_completed' do
    it 'logs completion with duration' do
      allow(log_subscriber).to receive(:info)

      log_subscriber.api_call_completed(build_event('api_call_completed', payload: { batch_size: 5, model: 'gpt-4', chapter_code: '01', duration_ms: 1234.56 }))

      expect(log_subscriber).to have_received(:info) do |json|
        entry = JSON.parse(json)
        expect(entry).to include('duration_ms' => 1234.56)
      end
    end
  end

  describe '#api_call_failed' do
    it 'logs failure with error and http status' do
      allow(log_subscriber).to receive(:error)

      log_subscriber.api_call_failed(build_event('api_call_failed', payload: { batch_size: 5, model: 'gpt-4', chapter_code: '01', error_class: 'Net::ReadTimeout', error_message: 'timeout', duration_ms: 500.0, http_status: 429 }))

      expect(log_subscriber).to have_received(:error) do |json|
        entry = JSON.parse(json)
        expect(entry).to include('error_class' => 'Net::ReadTimeout', 'http_status' => 429)
      end
    end
  end

  describe '#reindex_started' do
    it 'logs reindex start' do
      allow(log_subscriber).to receive(:info)

      log_subscriber.reindex_started(build_event('reindex_started'))

      expect(log_subscriber).to have_received(:info) do |json|
        entry = JSON.parse(json)
        expect(entry).to include('service' => 'self_text_generator', 'event' => 'reindex_started')
      end
    end
  end

  describe '#reindex_completed' do
    it 'logs reindex completion' do
      allow(log_subscriber).to receive(:info)

      log_subscriber.reindex_completed(build_event('reindex_completed'))

      expect(log_subscriber).to have_received(:info) do |json|
        entry = JSON.parse(json)
        expect(entry).to include('service' => 'self_text_generator', 'event' => 'reindex_completed')
      end
    end
  end
end
