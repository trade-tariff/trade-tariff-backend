module XiCnImporter
  module Instrumentation
    NAMESPACE = 'xi_cn_importer'.freeze

    extend self

    def import_run_started
      instrument('import_run_started')
    end

    def import_run_completed(imported:, failed:, duration_ms:)
      instrument('import_run_completed', imported:, failed:, duration_ms:)
    end

    def import_run_failed(error_class:, error_message:)
      instrument('import_run_failed', error_class:, error_message:)
    end

    def document_fetched(celex:, duration_ms:)
      instrument('document_fetched', celex:, duration_ms:)
    end

    def fetch_failed(url:, error_class:, error_message:)
      instrument('fetch_failed', url:, error_class:, error_message:)
    end

    def fetch_retry(url:, attempt:, max_attempts:, error_class:, error_message:, error_code:, backoff_seconds:)
      instrument(
        'fetch_retry',
        url:,
        attempt:,
        max_attempts:,
        error_class:,
        error_message:,
        error_code:,
        backoff_seconds:,
      )
    end

    def sparql_retry_attempt(attempt:, max_attempts:, error_class:, error_message:, error_code:, count: 1)
      instrument(
        'sparql_retry_attempt',
        attempt:,
        max_attempts:,
        error_class:,
        error_message:,
        error_code:,
        count:,
      )
    end

    def sparql_success_after_retry(retry_attempts:, count: 1)
      instrument('sparql_success_after_retry', retry_attempts:, count:)
    end

    def document_imported(celex:, duration_ms:)
      instrument('document_imported', celex:, duration_ms:)
    end

    def document_import_failed(celex:, error_class:, error_message:)
      instrument('document_import_failed', celex:, error_class:, error_message:)
    end

    def duplicate_notification_attempt(celex:, duplicate_attempt:, count: 1)
      instrument('duplicate_notification_attempt', celex:, duplicate_attempt:, count:)
    end

    def reimport_failed(version:, error_class:, error_message:)
      instrument('reimport_failed', version:, error_class:, error_message:)
    end

  private

    def instrument(event, payload = {})
      ActiveSupport::Notifications.instrument("#{event}.#{NAMESPACE}", payload)
    end
  end
end
