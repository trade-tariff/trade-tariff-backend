RSpec.describe CustomsTariffImporter::Logger do
  let(:log_subscriber) { described_class.new }

  def build_event(event_name, payload: {}, duration: 0.0)
    ActiveSupport::Notifications::Event.new(
      "#{event_name}.customs_tariff_importer",
      Time.current - (duration / 1000.0),
      Time.current,
      SecureRandom.hex(5),
      payload,
    )
  end

  describe '#import_run_started' do
    it 'logs a JSON entry' do
      allow(log_subscriber).to receive(:info)

      log_subscriber.import_run_started(build_event('import_run_started'))

      expect(log_subscriber).to have_received(:info) do |json|
        entry = JSON.parse(json)
        expect(entry).to include('service' => 'customs_tariff_importer', 'event' => 'import_run_started')
      end
    end
  end

  describe '#import_run_completed' do
    it 'logs run totals' do
      allow(log_subscriber).to receive(:info)

      log_subscriber.import_run_completed(build_event(
                                            'import_run_completed',
                                            payload: { imported: 2, skipped: 1, failed: 0, duration_ms: 3500.0 },
                                          ))

      expect(log_subscriber).to have_received(:info) do |json|
        entry = JSON.parse(json)
        expect(entry).to include('imported' => 2, 'skipped' => 1, 'failed' => 0, 'duration_ms' => 3500.0)
      end
    end
  end

  describe '#import_run_failed' do
    it 'logs error details at error level' do
      allow(log_subscriber).to receive(:error)

      log_subscriber.import_run_failed(build_event(
                                         'import_run_failed',
                                         payload: { error_class: 'RuntimeError', error_message: 'boom' },
                                       ))

      expect(log_subscriber).to have_received(:error) do |json|
        entry = JSON.parse(json)
        expect(entry).to include('event' => 'import_run_failed', 'error_class' => 'RuntimeError', 'error_message' => 'boom')
      end
    end
  end

  describe '#fetch_started' do
    it 'logs the URL' do
      allow(log_subscriber).to receive(:info)

      log_subscriber.fetch_started(build_event('fetch_started', payload: { url: 'https://example.com' }))

      expect(log_subscriber).to have_received(:info) do |json|
        entry = JSON.parse(json)
        expect(entry).to include('event' => 'fetch_started', 'url' => 'https://example.com')
      end
    end
  end

  describe '#document_fetched' do
    it 'logs version and duration' do
      allow(log_subscriber).to receive(:info)

      log_subscriber.document_fetched(build_event('document_fetched', payload: { version: '1.30', duration_ms: 250.5 }))

      expect(log_subscriber).to have_received(:info) do |json|
        entry = JSON.parse(json)
        expect(entry).to include('event' => 'document_fetched', 'version' => '1.30', 'duration_ms' => 250.5)
      end
    end
  end

  describe '#fetch_failed' do
    it 'logs error details at error level' do
      allow(log_subscriber).to receive(:error)

      log_subscriber.fetch_failed(build_event(
                                    'fetch_failed',
                                    payload: { url: 'https://example.com', error_class: 'Net::ReadTimeout', error_message: 'timeout' },
                                  ))

      expect(log_subscriber).to have_received(:error) do |json|
        entry = JSON.parse(json)
        expect(entry).to include('event' => 'fetch_failed', 'error_class' => 'Net::ReadTimeout', 'error_message' => 'timeout')
      end
    end
  end

  describe '#parse_started' do
    it 'logs the version' do
      allow(log_subscriber).to receive(:info)

      log_subscriber.parse_started(build_event('parse_started', payload: { version: '1.30' }))

      expect(log_subscriber).to have_received(:info) do |json|
        entry = JSON.parse(json)
        expect(entry).to include('event' => 'parse_started', 'version' => '1.30')
      end
    end
  end

  describe '#document_parsed' do
    it 'logs parse counts and duration' do
      allow(log_subscriber).to receive(:info)

      log_subscriber.document_parsed(build_event(
                                       'document_parsed',
                                       payload: { version: '1.30', chapters: 21, sections: 99, rules: 6, duration_ms: 1200.0 },
                                     ))

      expect(log_subscriber).to have_received(:info) do |json|
        entry = JSON.parse(json)
        expect(entry).to include('chapters' => 21, 'sections' => 99, 'rules' => 6, 'duration_ms' => 1200.0)
      end
    end
  end

  describe '#parse_failed' do
    it 'logs error details at error level' do
      allow(log_subscriber).to receive(:error)

      log_subscriber.parse_failed(build_event(
                                    'parse_failed',
                                    payload: { version: '1.30', error_class: 'ArgumentError', error_message: 'bad docx' },
                                  ))

      expect(log_subscriber).to have_received(:error) do |json|
        entry = JSON.parse(json)
        expect(entry).to include('event' => 'parse_failed', 'version' => '1.30', 'error_class' => 'ArgumentError')
      end
    end
  end

  describe '#document_skipped' do
    it 'logs the version and reason' do
      allow(log_subscriber).to receive(:info)

      log_subscriber.document_skipped(build_event('document_skipped', payload: { version: '1.30', reason: 'already_imported' }))

      expect(log_subscriber).to have_received(:info) do |json|
        entry = JSON.parse(json)
        expect(entry).to include('event' => 'document_skipped', 'version' => '1.30', 'reason' => 'already_imported')
      end
    end
  end

  describe '#document_imported' do
    it 'logs version and duration' do
      allow(log_subscriber).to receive(:info)

      log_subscriber.document_imported(build_event('document_imported', payload: { version: '1.30', duration_ms: 800.0 }))

      expect(log_subscriber).to have_received(:info) do |json|
        entry = JSON.parse(json)
        expect(entry).to include('event' => 'document_imported', 'version' => '1.30', 'duration_ms' => 800.0)
      end
    end
  end

  describe '#document_import_failed' do
    it 'logs error details at error level' do
      allow(log_subscriber).to receive(:error)

      log_subscriber.document_import_failed(build_event(
                                              'document_import_failed',
                                              payload: { version: '1.30', error_class: 'ActiveRecord::RecordInvalid', error_message: 'invalid' },
                                            ))

      expect(log_subscriber).to have_received(:error) do |json|
        entry = JSON.parse(json)
        expect(entry).to include('event' => 'document_import_failed', 'version' => '1.30', 'error_class' => 'ActiveRecord::RecordInvalid')
      end
    end
  end
end
