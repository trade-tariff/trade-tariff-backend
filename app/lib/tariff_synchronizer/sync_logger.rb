require 'active_support/log_subscriber'

module TariffSynchronizer
  class SyncLogger < ActiveSupport::LogSubscriber
    # Sync lifecycle

    def sync_run_started(event)
      info log_entry(
        event: 'sync_run_started',
        trade_service: event.payload[:service],
        run_id: event.payload[:run_id],
        triggered_by: event.payload[:triggered_by],
      )
    end

    def sync_run_completed(event)
      info log_entry(
        event: 'sync_run_completed',
        trade_service: event.payload[:service],
        run_id: event.payload[:run_id],
        duration_ms: event.payload[:duration_ms],
        files_downloaded: event.payload[:files_downloaded],
        files_applied: event.payload[:files_applied],
      )
    end

    def sync_run_failed(event)
      error log_entry(
        event: 'sync_run_failed',
        trade_service: event.payload[:service],
        run_id: event.payload[:run_id],
        phase: event.payload[:phase],
        error_class: event.payload[:error_class],
        error_message: event.payload[:error_message],
      )
    end

    # Download phase

    def download_started(event)
      info log_entry(
        event: 'download_started',
        trade_service: event.payload[:service],
        run_id: event.payload[:run_id],
      )
    end

    def download_completed(event)
      info log_entry(
        event: 'download_completed',
        trade_service: event.payload[:service],
        run_id: event.payload[:run_id],
        duration_ms: event.payload[:duration_ms],
        files_count: event.payload[:files_count],
      )
    end

    def file_downloaded(event)
      info log_entry(
        event: 'file_downloaded',
        trade_service: event.payload[:service],
        run_id: event.payload[:run_id],
        filename: event.payload[:filename],
        filesize: event.payload[:filesize],
      )
    end

    def download_failed(event)
      error log_entry(
        event: 'download_failed',
        trade_service: event.payload[:service],
        run_id: event.payload[:run_id],
        url: event.payload[:url],
        error_type: event.payload[:error_type],
      )
    end

    def download_retried(event)
      warn log_entry(
        event: 'download_retried',
        trade_service: event.payload[:service],
        run_id: event.payload[:run_id],
        url: event.payload[:url],
        attempt: event.payload[:attempt],
        reason: event.payload[:reason],
      )
    end

    def download_retry_exhausted(event)
      warn log_entry(
        event: 'download_retry_exhausted',
        trade_service: event.payload[:service],
        run_id: event.payload[:run_id],
        url: event.payload[:url],
      )
    end

    def download_delayed(event)
      info log_entry(
        event: 'download_delayed',
        trade_service: event.payload[:service],
        run_id: event.payload[:run_id],
        retry_at: event.payload[:retry_at],
      )
    end

    # Apply phase

    def apply_started(event)
      info log_entry(
        event: 'apply_started',
        trade_service: event.payload[:service],
        run_id: event.payload[:run_id],
        pending_count: event.payload[:pending_count],
      )
    end

    def apply_completed(event)
      info log_entry(
        event: 'apply_completed',
        trade_service: event.payload[:service],
        run_id: event.payload[:run_id],
        duration_ms: event.payload[:duration_ms],
        files_applied: event.payload[:files_applied],
      )
    end

    def file_import_started(event)
      info log_entry(
        event: 'file_import_started',
        trade_service: event.payload[:service],
        run_id: event.payload[:run_id],
        filename: event.payload[:filename],
      )
    end

    def file_import_completed(event)
      info log_entry(
        event: 'file_import_completed',
        trade_service: event.payload[:service],
        run_id: event.payload[:run_id],
        filename: event.payload[:filename],
        duration_ms: event.payload[:duration_ms],
        creates: event.payload[:creates],
        updates: event.payload[:updates],
        destroys: event.payload[:destroys],
      )
    end

    def file_import_failed(event)
      error log_entry(
        event: 'file_import_failed',
        trade_service: event.payload[:service],
        run_id: event.payload[:run_id],
        filename: event.payload[:filename],
        error_class: event.payload[:error_class],
        error_message: event.payload[:error_message],
      )
    end

    # Infrastructure

    def lock_acquired(event)
      debug log_entry(
        event: 'lock_acquired',
        trade_service: event.payload[:service],
        run_id: event.payload[:run_id],
        phase: event.payload[:phase],
      )
    end

    def lock_failed(event)
      warn log_entry(
        event: 'lock_failed',
        trade_service: event.payload[:service],
        run_id: event.payload[:run_id],
        phase: event.payload[:phase],
      )
    end

    def sequence_check_passed(event)
      debug log_entry(
        event: 'sequence_check_passed',
        trade_service: event.payload[:service],
        run_id: event.payload[:run_id],
      )
    end

    def sequence_check_failed(event)
      error log_entry(
        event: 'sequence_check_failed',
        trade_service: event.payload[:service],
        run_id: event.payload[:run_id],
        details: event.payload[:details],
      )
    end

    def failed_updates_detected(event)
      error log_entry(
        event: 'failed_updates_detected',
        trade_service: event.payload[:service],
        run_id: event.payload[:run_id],
        filenames: event.payload[:filenames],
      )
    end

    # Rollback

    def rollback_started(event)
      info log_entry(
        event: 'rollback_started',
        trade_service: event.payload[:service],
        run_id: event.payload[:run_id],
        rollback_date: event.payload[:rollback_date],
        keep: event.payload[:keep],
      )
    end

    def rollback_completed(event)
      info log_entry(
        event: 'rollback_completed',
        trade_service: event.payload[:service],
        run_id: event.payload[:run_id],
        rollback_date: event.payload[:rollback_date],
        duration_ms: event.payload[:duration_ms],
        files_count: event.payload[:files_count],
      )
    end

    private

    def log_entry(data)
      data.merge(
        service: 'tariff_sync',
        timestamp: Time.current.iso8601,
      ).to_json
    end
  end
end

TariffSynchronizer::SyncLogger.attach_to :tariff_sync unless Rails.env.test?
