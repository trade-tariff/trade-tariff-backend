RSpec.describe CustomsTariffImporter::Instrumentation do
  describe '.instrument' do
    it 'emits events with the .customs_tariff_importer namespace' do
      allow(ActiveSupport::Notifications).to receive(:instrument)

      described_class.instrument('test_event', foo: 'bar')

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'test_event.customs_tariff_importer',
        hash_including(foo: 'bar'),
      )
    end
  end

  describe '.import_run_started' do
    it 'emits import_run_started' do
      allow(ActiveSupport::Notifications).to receive(:instrument)
      described_class.import_run_started
      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'import_run_started.customs_tariff_importer', {}
      )
    end
  end

  describe '.import_run_completed' do
    it 'emits import_run_completed with counts and duration' do
      allow(ActiveSupport::Notifications).to receive(:instrument)
      described_class.import_run_completed(imported: 2, skipped: 1, failed: 0, duration_ms: 1500.0)
      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'import_run_completed.customs_tariff_importer',
        hash_including(imported: 2, skipped: 1, failed: 0, duration_ms: 1500.0),
      )
    end
  end

  describe '.import_run_failed' do
    it 'emits import_run_failed with error details' do
      allow(ActiveSupport::Notifications).to receive(:instrument)
      described_class.import_run_failed(error_class: 'RuntimeError', error_message: 'boom')
      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'import_run_failed.customs_tariff_importer',
        hash_including(error_class: 'RuntimeError', error_message: 'boom'),
      )
    end
  end

  describe '.document_fetched' do
    it 'emits document_fetched with version and timing' do
      allow(ActiveSupport::Notifications).to receive(:instrument)
      described_class.document_fetched(version: '1.30', duration_ms: 320.5)
      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'document_fetched.customs_tariff_importer',
        hash_including(version: '1.30', duration_ms: 320.5),
      )
    end
  end

  describe '.fetch_failed' do
    it 'emits fetch_failed with url and error details' do
      allow(ActiveSupport::Notifications).to receive(:instrument)
      described_class.fetch_failed(url: 'https://example.com', error_class: 'RuntimeError', error_message: 'timeout')
      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'fetch_failed.customs_tariff_importer',
        hash_including(url: 'https://example.com', error_class: 'RuntimeError', error_message: 'timeout'),
      )
    end
  end

  describe '.document_parsed' do
    it 'emits document_parsed with content counts and timing' do
      allow(ActiveSupport::Notifications).to receive(:instrument)
      described_class.document_parsed(version: '1.30', chapters: 97, sections: 21, rules: 6, duration_ms: 850.0)
      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'document_parsed.customs_tariff_importer',
        hash_including(version: '1.30', chapters: 97, sections: 21, rules: 6, duration_ms: 850.0),
      )
    end
  end

  describe '.parse_failed' do
    it 'emits parse_failed with version and error details' do
      allow(ActiveSupport::Notifications).to receive(:instrument)
      described_class.parse_failed(version: '1.30', error_class: 'RuntimeError', error_message: 'bad xml')
      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'parse_failed.customs_tariff_importer',
        hash_including(version: '1.30', error_class: 'RuntimeError', error_message: 'bad xml'),
      )
    end
  end

  describe '.document_skipped' do
    it 'emits document_skipped with version and reason' do
      allow(ActiveSupport::Notifications).to receive(:instrument)
      described_class.document_skipped(version: '1.30', reason: :already_imported)
      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'document_skipped.customs_tariff_importer',
        hash_including(version: '1.30', reason: :already_imported),
      )
    end
  end

  describe '.document_imported' do
    it 'emits document_imported with version and timing' do
      allow(ActiveSupport::Notifications).to receive(:instrument)
      described_class.document_imported(version: '1.30', duration_ms: 2100.0)
      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'document_imported.customs_tariff_importer',
        hash_including(version: '1.30', duration_ms: 2100.0),
      )
    end
  end

  describe '.document_import_failed' do
    it 'emits document_import_failed with version and error details' do
      allow(ActiveSupport::Notifications).to receive(:instrument)
      described_class.document_import_failed(version: '1.30', error_class: 'Sequel::Error', error_message: 'db error')
      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'document_import_failed.customs_tariff_importer',
        hash_including(version: '1.30', error_class: 'Sequel::Error', error_message: 'db error'),
      )
    end
  end
end
