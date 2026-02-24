require 'stringio'

RSpec.describe TariffSynchronizer::SyncLogger do
  let(:log_output) { StringIO.new }
  let(:test_logger) { ActiveSupport::Logger.new(log_output) }
  let(:logger_instance) do
    logger = test_logger
    described_class.new.tap do |l|
      l.define_singleton_method(:logger) { logger }
    end
  end

  def build_event(name, payload)
    ActiveSupport::Notifications::Event.new(
      "#{name}.tariff_sync",
      Time.current,
      Time.current,
      SecureRandom.hex(10),
      payload,
    )
  end

  def parsed_log_output
    log_output.rewind
    lines = log_output.read.strip.split("\n")
    JSON.parse(lines.last)
  end

  shared_examples 'a tariff_sync log entry' do |method_name, event_name, payload|
    it 'includes timestamp' do
      logger_instance.public_send(method_name, build_event(event_name, payload))
      json = parsed_log_output
      expect(json['timestamp']).to be_present
    end
  end

  describe '#sync_run_started' do
    let(:payload) { { service: 'uk', run_id: 'run-1', triggered_by: 'CdsUpdatesSynchronizerWorker' } }

    it_behaves_like 'a tariff_sync log entry', :sync_run_started, 'sync_run_started',
                    { service: 'uk', run_id: 'run-1', triggered_by: 'CdsUpdatesSynchronizerWorker' }

    it 'logs correct fields' do
      logger_instance.sync_run_started(build_event('sync_run_started', payload))
      json = parsed_log_output
      expect(json['event']).to eq('sync_run_started')
      expect(json['service']).to eq('uk')
      expect(json['run_id']).to eq('run-1')
      expect(json['triggered_by']).to eq('CdsUpdatesSynchronizerWorker')
    end
  end

  describe '#sync_run_completed' do
    let(:payload) { { service: 'uk', run_id: 'run-1', duration_ms: 5000.0, files_downloaded: 3, files_applied: 2 } }

    it 'logs correct fields' do
      logger_instance.sync_run_completed(build_event('sync_run_completed', payload))
      json = parsed_log_output
      expect(json['event']).to eq('sync_run_completed')
      expect(json['duration_ms']).to eq(5000.0)
      expect(json['files_downloaded']).to eq(3)
      expect(json['files_applied']).to eq(2)
    end
  end

  describe '#sync_run_failed' do
    let(:payload) { { service: 'uk', run_id: 'run-1', phase: 'download', error_class: 'RuntimeError', error_message: 'boom' } }

    it 'logs at error level with correct fields' do
      logger_instance.sync_run_failed(build_event('sync_run_failed', payload))
      json = parsed_log_output
      expect(json['event']).to eq('sync_run_failed')
      expect(json['phase']).to eq('download')
      expect(json['error_class']).to eq('RuntimeError')
      expect(json['error_message']).to eq('boom')
    end
  end

  describe '#download_started' do
    let(:payload) { { service: 'uk', run_id: 'run-1' } }

    it 'logs correct fields' do
      logger_instance.download_started(build_event('download_started', payload))
      json = parsed_log_output
      expect(json['event']).to eq('download_started')
      expect(json['service']).to eq('uk')
    end
  end

  describe '#download_completed' do
    let(:payload) { { service: 'uk', run_id: 'run-1', duration_ms: 1200.5, files_count: 5 } }

    it 'logs correct fields' do
      logger_instance.download_completed(build_event('download_completed', payload))
      json = parsed_log_output
      expect(json['event']).to eq('download_completed')
      expect(json['duration_ms']).to eq(1200.5)
      expect(json['files_count']).to eq(5)
    end
  end

  describe '#file_downloaded' do
    let(:payload) { { service: 'uk', run_id: 'run-1', filename: 'update.gzip', filesize: 1024 } }

    it 'logs correct fields' do
      logger_instance.file_downloaded(build_event('file_downloaded', payload))
      json = parsed_log_output
      expect(json['event']).to eq('file_downloaded')
      expect(json['filename']).to eq('update.gzip')
      expect(json['filesize']).to eq(1024)
    end
  end

  describe '#download_failed' do
    let(:payload) { { service: 'uk', run_id: 'run-1', url: 'https://example.com', error_type: 'Faraday::TimeoutError' } }

    it 'logs at error level with correct fields' do
      logger_instance.download_failed(build_event('download_failed', payload))
      json = parsed_log_output
      expect(json['event']).to eq('download_failed')
      expect(json['url']).to eq('https://example.com')
      expect(json['error_type']).to eq('Faraday::TimeoutError')
    end
  end

  describe '#download_retried' do
    let(:payload) { { service: 'uk', run_id: 'run-1', url: 'https://example.com', attempt: 3, reason: 'response_code_403' } }

    it 'logs at warn level with correct fields' do
      logger_instance.download_retried(build_event('download_retried', payload))
      json = parsed_log_output
      expect(json['event']).to eq('download_retried')
      expect(json['attempt']).to eq(3)
      expect(json['reason']).to eq('response_code_403')
    end
  end

  describe '#download_retry_exhausted' do
    let(:payload) { { service: 'uk', run_id: 'run-1', url: 'https://example.com' } }

    it 'logs at warn level' do
      logger_instance.download_retry_exhausted(build_event('download_retry_exhausted', payload))
      json = parsed_log_output
      expect(json['event']).to eq('download_retry_exhausted')
      expect(json['url']).to eq('https://example.com')
    end
  end

  describe '#download_delayed' do
    let(:payload) { { service: 'uk', run_id: 'run-1', retry_at: '2024-01-01T10:00:00Z' } }

    it 'logs correct fields' do
      logger_instance.download_delayed(build_event('download_delayed', payload))
      json = parsed_log_output
      expect(json['event']).to eq('download_delayed')
      expect(json['retry_at']).to eq('2024-01-01T10:00:00Z')
    end
  end

  describe '#apply_started' do
    let(:payload) { { service: 'uk', run_id: 'run-1', pending_count: 3 } }

    it 'logs correct fields' do
      logger_instance.apply_started(build_event('apply_started', payload))
      json = parsed_log_output
      expect(json['event']).to eq('apply_started')
      expect(json['pending_count']).to eq(3)
    end
  end

  describe '#apply_completed' do
    let(:payload) { { service: 'uk', run_id: 'run-1', duration_ms: 30_000.0, files_applied: 2 } }

    it 'logs correct fields' do
      logger_instance.apply_completed(build_event('apply_completed', payload))
      json = parsed_log_output
      expect(json['event']).to eq('apply_completed')
      expect(json['duration_ms']).to eq(30_000.0)
      expect(json['files_applied']).to eq(2)
    end
  end

  describe '#file_import_started' do
    let(:payload) { { service: 'uk', run_id: 'run-1', filename: 'update.gzip' } }

    it 'logs correct fields' do
      logger_instance.file_import_started(build_event('file_import_started', payload))
      json = parsed_log_output
      expect(json['event']).to eq('file_import_started')
      expect(json['filename']).to eq('update.gzip')
    end
  end

  describe '#file_import_completed' do
    let(:payload) { { service: 'uk', run_id: 'run-1', filename: 'update.gzip', duration_ms: 5000.0, creates: 10, updates: 5, destroys: 2 } }

    it 'logs correct fields' do
      logger_instance.file_import_completed(build_event('file_import_completed', payload))
      json = parsed_log_output
      expect(json['event']).to eq('file_import_completed')
      expect(json['filename']).to eq('update.gzip')
      expect(json['creates']).to eq(10)
      expect(json['updates']).to eq(5)
      expect(json['destroys']).to eq(2)
    end
  end

  describe '#file_import_failed' do
    let(:payload) { { service: 'uk', run_id: 'run-1', filename: 'update.gzip', error_class: 'RuntimeError', error_message: 'bad data' } }

    it 'logs at error level with correct fields' do
      logger_instance.file_import_failed(build_event('file_import_failed', payload))
      json = parsed_log_output
      expect(json['event']).to eq('file_import_failed')
      expect(json['error_class']).to eq('RuntimeError')
      expect(json['error_message']).to eq('bad data')
    end
  end

  describe '#lock_acquired' do
    let(:payload) { { service: 'uk', run_id: 'run-1', phase: 'download' } }

    it 'logs at debug level' do
      logger_instance.lock_acquired(build_event('lock_acquired', payload))
      json = parsed_log_output
      expect(json['event']).to eq('lock_acquired')
      expect(json['phase']).to eq('download')
    end
  end

  describe '#lock_failed' do
    let(:payload) { { service: 'uk', run_id: 'run-1', phase: 'apply' } }

    it 'logs at warn level' do
      logger_instance.lock_failed(build_event('lock_failed', payload))
      json = parsed_log_output
      expect(json['event']).to eq('lock_failed')
      expect(json['phase']).to eq('apply')
    end
  end

  describe '#sequence_check_passed' do
    let(:payload) { { service: 'uk', run_id: 'run-1' } }

    it 'logs at debug level' do
      logger_instance.sequence_check_passed(build_event('sequence_check_passed', payload))
      json = parsed_log_output
      expect(json['event']).to eq('sequence_check_passed')
    end
  end

  describe '#sequence_check_failed' do
    let(:payload) { { service: 'uk', run_id: 'run-1', details: 'Wrong sequence' } }

    it 'logs at error level' do
      logger_instance.sequence_check_failed(build_event('sequence_check_failed', payload))
      json = parsed_log_output
      expect(json['event']).to eq('sequence_check_failed')
      expect(json['details']).to eq('Wrong sequence')
    end
  end

  describe '#failed_updates_detected' do
    let(:payload) { { service: 'uk', run_id: 'run-1', filenames: %w[file1.gzip file2.gzip] } }

    it 'logs at error level' do
      logger_instance.failed_updates_detected(build_event('failed_updates_detected', payload))
      json = parsed_log_output
      expect(json['event']).to eq('failed_updates_detected')
      expect(json['filenames']).to eq(%w[file1.gzip file2.gzip])
    end
  end

  describe '#rollback_started' do
    let(:payload) { { service: 'uk', run_id: 'run-1', rollback_date: '2024-01-01', keep: false } }

    it 'logs correct fields' do
      logger_instance.rollback_started(build_event('rollback_started', payload))
      json = parsed_log_output
      expect(json['event']).to eq('rollback_started')
      expect(json['rollback_date']).to eq('2024-01-01')
      expect(json['keep']).to be(false)
    end
  end

  describe '#rollback_completed' do
    let(:payload) { { service: 'uk', run_id: 'run-1', rollback_date: '2024-01-01', duration_ms: 10_000.0, files_count: 5 } }

    it 'logs correct fields' do
      logger_instance.rollback_completed(build_event('rollback_completed', payload))
      json = parsed_log_output
      expect(json['event']).to eq('rollback_completed')
      expect(json['rollback_date']).to eq('2024-01-01')
      expect(json['duration_ms']).to eq(10_000.0)
      expect(json['files_count']).to eq(5)
    end
  end
end
