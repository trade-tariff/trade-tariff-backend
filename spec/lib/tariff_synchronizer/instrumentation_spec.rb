RSpec.describe TariffSynchronizer::Instrumentation do
  before do
    allow(TradeTariffBackend).to receive(:service).and_return('uk')
    Thread.current[:tariff_sync_run_id] = 'test-run-123'
  end

  after do
    Thread.current[:tariff_sync_run_id] = nil
  end

  describe '.instrument' do
    it 'emits events with the .tariff_sync namespace' do
      allow(ActiveSupport::Notifications).to receive(:instrument)

      described_class.instrument('test_event', foo: 'bar')

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'test_event.tariff_sync',
        hash_including(foo: 'bar', service: 'uk', run_id: 'test-run-123'),
      )
    end

    it 'automatically includes service and run_id' do
      allow(ActiveSupport::Notifications).to receive(:instrument)

      described_class.instrument('test_event')

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'test_event.tariff_sync',
        hash_including(service: 'uk', run_id: 'test-run-123'),
      )
    end
  end

  describe '.sync_run_started' do
    it 'instruments the sync_run_started event' do
      allow(ActiveSupport::Notifications).to receive(:instrument)

      described_class.sync_run_started(triggered_by: 'CdsUpdatesSynchronizerWorker')

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'sync_run_started.tariff_sync',
        hash_including(triggered_by: 'CdsUpdatesSynchronizerWorker', service: 'uk'),
      )
    end
  end

  describe '.sync_run_completed' do
    it 'instruments the sync_run_completed event' do
      allow(ActiveSupport::Notifications).to receive(:instrument)

      described_class.sync_run_completed(duration_ms: 5000.0, files_downloaded: 3, files_applied: 2)

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'sync_run_completed.tariff_sync',
        hash_including(duration_ms: 5000.0, files_downloaded: 3, files_applied: 2),
      )
    end
  end

  describe '.sync_run_failed' do
    it 'instruments the sync_run_failed event' do
      allow(ActiveSupport::Notifications).to receive(:instrument)

      described_class.sync_run_failed(phase: 'download', error_class: 'RuntimeError', error_message: 'boom')

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'sync_run_failed.tariff_sync',
        hash_including(phase: 'download', error_class: 'RuntimeError', error_message: 'boom'),
      )
    end
  end

  describe '.download_started' do
    it 'instruments the download_started event' do
      allow(ActiveSupport::Notifications).to receive(:instrument)

      described_class.download_started

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'download_started.tariff_sync',
        hash_including(service: 'uk'),
      )
    end

    it 'accepts an optional filename' do
      allow(ActiveSupport::Notifications).to receive(:instrument)

      described_class.download_started(filename: 'cds_daily_list_2024-01-01')

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'download_started.tariff_sync',
        hash_including(filename: 'cds_daily_list_2024-01-01'),
      )
    end
  end

  describe '.download_completed' do
    it 'instruments the download_completed event' do
      allow(ActiveSupport::Notifications).to receive(:instrument)

      described_class.download_completed(duration_ms: 1200.5, files_count: 5)

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'download_completed.tariff_sync',
        hash_including(duration_ms: 1200.5, files_count: 5),
      )
    end
  end

  describe '.file_downloaded' do
    it 'instruments the file_downloaded event' do
      allow(ActiveSupport::Notifications).to receive(:instrument)

      described_class.file_downloaded(filename: 'update.gzip', filesize: 1024)

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'file_downloaded.tariff_sync',
        hash_including(filename: 'update.gzip', filesize: 1024),
      )
    end
  end

  describe '.download_failed' do
    it 'instruments the download_failed event' do
      allow(ActiveSupport::Notifications).to receive(:instrument)

      described_class.download_failed(url: 'https://example.com/update', error_type: 'Faraday::TimeoutError')

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'download_failed.tariff_sync',
        hash_including(url: 'https://example.com/update', error_type: 'Faraday::TimeoutError'),
      )
    end
  end

  describe '.download_retried' do
    it 'instruments the download_retried event' do
      allow(ActiveSupport::Notifications).to receive(:instrument)

      described_class.download_retried(url: 'https://example.com/update', attempt: 3, reason: 'response_code_403')

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'download_retried.tariff_sync',
        hash_including(url: 'https://example.com/update', attempt: 3, reason: 'response_code_403'),
      )
    end
  end

  describe '.download_retry_exhausted' do
    it 'instruments the download_retry_exhausted event' do
      allow(ActiveSupport::Notifications).to receive(:instrument)

      described_class.download_retry_exhausted(url: 'https://example.com/update')

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'download_retry_exhausted.tariff_sync',
        hash_including(url: 'https://example.com/update'),
      )
    end
  end

  describe '.download_delayed' do
    it 'instruments the download_delayed event' do
      allow(ActiveSupport::Notifications).to receive(:instrument)

      described_class.download_delayed(retry_at: '2024-01-01T10:00:00Z')

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'download_delayed.tariff_sync',
        hash_including(retry_at: '2024-01-01T10:00:00Z'),
      )
    end
  end

  describe '.apply_started' do
    it 'instruments the apply_started event' do
      allow(ActiveSupport::Notifications).to receive(:instrument)

      described_class.apply_started(pending_count: 3)

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'apply_started.tariff_sync',
        hash_including(pending_count: 3),
      )
    end
  end

  describe '.apply_completed' do
    it 'instruments the apply_completed event' do
      allow(ActiveSupport::Notifications).to receive(:instrument)

      described_class.apply_completed(duration_ms: 30_000.0, files_applied: 2)

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'apply_completed.tariff_sync',
        hash_including(duration_ms: 30_000.0, files_applied: 2),
      )
    end
  end

  describe '.file_import_started' do
    it 'instruments the file_import_started event' do
      allow(ActiveSupport::Notifications).to receive(:instrument)

      described_class.file_import_started(filename: 'update.gzip')

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'file_import_started.tariff_sync',
        hash_including(filename: 'update.gzip'),
      )
    end
  end

  describe '.file_import_completed' do
    it 'instruments the file_import_completed event' do
      allow(ActiveSupport::Notifications).to receive(:instrument)

      described_class.file_import_completed(filename: 'update.gzip', duration_ms: 5000.0, creates: 10, updates: 5, destroys: 2)

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'file_import_completed.tariff_sync',
        hash_including(filename: 'update.gzip', duration_ms: 5000.0, creates: 10, updates: 5, destroys: 2),
      )
    end
  end

  describe '.file_import_failed' do
    it 'instruments the file_import_failed event' do
      allow(ActiveSupport::Notifications).to receive(:instrument)

      described_class.file_import_failed(filename: 'update.gzip', error_class: 'RuntimeError', error_message: 'bad data')

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'file_import_failed.tariff_sync',
        hash_including(filename: 'update.gzip', error_class: 'RuntimeError', error_message: 'bad data'),
      )
    end
  end

  describe '.lock_acquired' do
    it 'instruments the lock_acquired event' do
      allow(ActiveSupport::Notifications).to receive(:instrument)

      described_class.lock_acquired(phase: 'download')

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'lock_acquired.tariff_sync',
        hash_including(phase: 'download'),
      )
    end
  end

  describe '.lock_failed' do
    it 'instruments the lock_failed event' do
      allow(ActiveSupport::Notifications).to receive(:instrument)

      described_class.lock_failed(phase: 'apply')

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'lock_failed.tariff_sync',
        hash_including(phase: 'apply'),
      )
    end
  end

  describe '.sequence_check_passed' do
    it 'instruments the sequence_check_passed event' do
      allow(ActiveSupport::Notifications).to receive(:instrument)

      described_class.sequence_check_passed

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'sequence_check_passed.tariff_sync',
        hash_including(service: 'uk'),
      )
    end
  end

  describe '.sequence_check_failed' do
    it 'instruments the sequence_check_failed event' do
      allow(ActiveSupport::Notifications).to receive(:instrument)

      described_class.sequence_check_failed(details: 'Wrong sequence')

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'sequence_check_failed.tariff_sync',
        hash_including(details: 'Wrong sequence'),
      )
    end
  end

  describe '.failed_updates_detected' do
    it 'instruments the failed_updates_detected event' do
      allow(ActiveSupport::Notifications).to receive(:instrument)

      described_class.failed_updates_detected(filenames: %w[file1.gzip file2.gzip])

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'failed_updates_detected.tariff_sync',
        hash_including(filenames: %w[file1.gzip file2.gzip]),
      )
    end
  end

  describe '.rollback_started' do
    it 'instruments the rollback_started event' do
      allow(ActiveSupport::Notifications).to receive(:instrument)

      described_class.rollback_started(rollback_date: '2024-01-01', keep: false)

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'rollback_started.tariff_sync',
        hash_including(rollback_date: '2024-01-01', keep: false),
      )
    end
  end

  describe '.rollback_completed' do
    it 'instruments the rollback_completed event' do
      allow(ActiveSupport::Notifications).to receive(:instrument)

      described_class.rollback_completed(rollback_date: '2024-01-01', duration_ms: 10_000.0, files_count: 5)

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'rollback_completed.tariff_sync',
        hash_including(rollback_date: '2024-01-01', duration_ms: 10_000.0, files_count: 5),
      )
    end
  end
end
