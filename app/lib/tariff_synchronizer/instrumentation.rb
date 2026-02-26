require 'active_support/notifications'

module TariffSynchronizer
  module Instrumentation
    module_function

    def instrument(event_name, payload = {}, &block)
      payload[:service] ||= TradeTariffBackend.service
      payload[:run_id] ||= Thread.current[:tariff_sync_run_id]
      ActiveSupport::Notifications.instrument("#{event_name}.tariff_sync", payload, &block)
    end

    # Sync lifecycle

    def sync_run_started(triggered_by:)
      instrument('sync_run_started', triggered_by:)
    end

    def sync_run_completed(duration_ms:, files_downloaded: 0, files_applied: 0)
      instrument('sync_run_completed', duration_ms:, files_downloaded:, files_applied:)
    end

    def sync_run_failed(phase:, error_class:, error_message:)
      instrument('sync_run_failed', phase:, error_class:, error_message:)
    end

    # Download phase

    def download_started(filename: nil)
      instrument('download_started', filename:)
    end

    def download_completed(duration_ms:, files_count:)
      instrument('download_completed', duration_ms:, files_count:)
    end

    def file_downloaded(filename:, filesize:)
      instrument('file_downloaded', filename:, filesize:)
    end

    def download_failed(url:, error_type:)
      instrument('download_failed', url:, error_type:)
    end

    def download_retried(url:, attempt:, reason:)
      instrument('download_retried', url:, attempt:, reason:)
    end

    def download_retry_exhausted(url:)
      instrument('download_retry_exhausted', url:)
    end

    def download_delayed(retry_at:)
      instrument('download_delayed', retry_at:)
    end

    # Apply phase

    def apply_started(pending_count:)
      instrument('apply_started', pending_count:)
    end

    def apply_completed(duration_ms:, files_applied:)
      instrument('apply_completed', duration_ms:, files_applied:)
    end

    def file_import_started(filename:)
      instrument('file_import_started', filename:)
    end

    def file_import_completed(filename:, duration_ms:, creates: 0, updates: 0, destroys: 0)
      instrument('file_import_completed', filename:, duration_ms:, creates:, updates:, destroys:)
    end

    def file_import_failed(filename:, error_class:, error_message:)
      instrument('file_import_failed', filename:, error_class:, error_message:)
    end

    # Infrastructure

    def lock_acquired(phase:)
      instrument('lock_acquired', phase:)
    end

    def lock_failed(phase:)
      instrument('lock_failed', phase:)
    end

    def sequence_check_passed
      instrument('sequence_check_passed')
    end

    def sequence_check_failed(details:)
      instrument('sequence_check_failed', details:)
    end

    def failed_updates_detected(filenames:)
      instrument('failed_updates_detected', filenames:)
    end

    # Rollback

    def rollback_started(rollback_date:, keep:)
      instrument('rollback_started', rollback_date:, keep:)
    end

    def rollback_completed(rollback_date:, duration_ms:, files_count:)
      instrument('rollback_completed', rollback_date:, duration_ms:, files_count:)
    end
  end
end
