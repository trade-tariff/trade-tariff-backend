RSpec.describe SelfTextGenerator::Instrumentation do
  describe '.generation_started' do
    it 'instruments with the correct event name and payload' do
      events = []
      ActiveSupport::Notifications.subscribe('generation_started.self_text_generator') do |*args|
        events << ActiveSupport::Notifications::Event.new(*args)
      end

      described_class.generation_started(total_chapters: 98)

      expect(events.size).to eq(1)
      expect(events.first.payload[:total_chapters]).to eq(98)
    ensure
      ActiveSupport::Notifications.unsubscribe('generation_started.self_text_generator')
    end
  end

  describe '.generation_completed' do
    it 'instruments with the correct event name' do
      events = []
      ActiveSupport::Notifications.subscribe('generation_completed.self_text_generator') do |*args|
        events << ActiveSupport::Notifications::Event.new(*args)
      end

      described_class.generation_completed

      expect(events.size).to eq(1)
    ensure
      ActiveSupport::Notifications.unsubscribe('generation_completed.self_text_generator')
    end
  end

  describe '.chapter_started' do
    it 'instruments with chapter details' do
      events = []
      ActiveSupport::Notifications.subscribe('chapter_started.self_text_generator') do |*args|
        events << ActiveSupport::Notifications::Event.new(*args)
      end

      described_class.chapter_started(chapter_sid: 123, chapter_code: '01')

      expect(events.size).to eq(1)
      expect(events.first.payload).to include(chapter_sid: 123, chapter_code: '01')
    ensure
      ActiveSupport::Notifications.unsubscribe('chapter_started.self_text_generator')
    end
  end

  describe '.chapter_completed' do
    it 'instruments with chapter details and yields payload' do
      events = []
      ActiveSupport::Notifications.subscribe('chapter_completed.self_text_generator') do |*args|
        events << ActiveSupport::Notifications::Event.new(*args)
      end

      described_class.chapter_completed(chapter_sid: 123, chapter_code: '01') do |payload|
        payload[:mechanical] = { processed: 5 }
        payload[:ai] = { processed: 2 }
      end

      expect(events.size).to eq(1)
      expect(events.first.payload).to include(
        chapter_sid: 123,
        chapter_code: '01',
        mechanical: { processed: 5 },
        ai: { processed: 2 },
      )
    ensure
      ActiveSupport::Notifications.unsubscribe('chapter_completed.self_text_generator')
    end
  end

  describe '.chapter_failed' do
    it 'instruments with error details' do
      events = []
      ActiveSupport::Notifications.subscribe('chapter_failed.self_text_generator') do |*args|
        events << ActiveSupport::Notifications::Event.new(*args)
      end

      error = StandardError.new('boom')
      described_class.chapter_failed(chapter_sid: 123, chapter_code: '01', error:)

      expect(events.size).to eq(1)
      expect(events.first.payload).to include(
        error_class: 'StandardError',
        error_message: 'boom',
      )
    ensure
      ActiveSupport::Notifications.unsubscribe('chapter_failed.self_text_generator')
    end
  end

  describe '.api_call' do
    it 'instruments start and completion, returning the block result' do
      started_events = []
      completed_events = []

      ActiveSupport::Notifications.subscribe('api_call_started.self_text_generator') do |*args|
        started_events << ActiveSupport::Notifications::Event.new(*args)
      end
      ActiveSupport::Notifications.subscribe('api_call_completed.self_text_generator') do |*args|
        completed_events << ActiveSupport::Notifications::Event.new(*args)
      end

      result = described_class.api_call(batch_size: 5, model: 'gpt-4', chapter_code: '01') { 'response' }

      expect(result).to eq('response')
      expect(started_events.size).to eq(1)
      expect(completed_events.size).to eq(1)
      expect(completed_events.first.payload[:duration_ms]).to be_a(Float)
    ensure
      ActiveSupport::Notifications.unsubscribe('api_call_started.self_text_generator')
      ActiveSupport::Notifications.unsubscribe('api_call_completed.self_text_generator')
    end
  end

  describe '.api_call on failure' do
    it 'instruments failure and re-raises' do
      failed_events = []
      ActiveSupport::Notifications.subscribe('api_call_failed.self_text_generator') do |*args|
        failed_events << ActiveSupport::Notifications::Event.new(*args)
      end

      expect {
        described_class.api_call(batch_size: 5, model: 'gpt-4', chapter_code: '01') { raise StandardError, 'timeout' }
      }.to raise_error(StandardError, 'timeout')

      expect(failed_events.size).to eq(1)
      expect(failed_events.first.payload).to include(
        error_class: 'StandardError',
        error_message: 'timeout',
      )
    ensure
      ActiveSupport::Notifications.unsubscribe('api_call_failed.self_text_generator')
    end
  end

  describe '.reindex_started' do
    it 'instruments with the correct event name' do
      events = []
      ActiveSupport::Notifications.subscribe('reindex_started.self_text_generator') do |*args|
        events << ActiveSupport::Notifications::Event.new(*args)
      end

      described_class.reindex_started

      expect(events.size).to eq(1)
    ensure
      ActiveSupport::Notifications.unsubscribe('reindex_started.self_text_generator')
    end
  end

  describe '.reindex_completed' do
    it 'instruments with the correct event name' do
      events = []
      ActiveSupport::Notifications.subscribe('reindex_completed.self_text_generator') do |*args|
        events << ActiveSupport::Notifications::Event.new(*args)
      end

      described_class.reindex_completed

      expect(events.size).to eq(1)
    ensure
      ActiveSupport::Notifications.unsubscribe('reindex_completed.self_text_generator')
    end
  end
end
