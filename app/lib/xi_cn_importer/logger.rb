require 'active_support/log_subscriber'

module XiCnImporter
  class Logger < ActiveSupport::LogSubscriber
    def import_run_started(_event)
      info log_entry(event: 'import_run_started')
    end

    def import_run_completed(event)
      info log_entry(
        event: 'import_run_completed',
        imported: event.payload[:imported],
        failed: event.payload[:failed],
        duration_ms: event.payload[:duration_ms],
      )
    end

    def import_run_failed(event)
      error log_entry(
        event: 'import_run_failed',
        error_class: event.payload[:error_class],
        error_message: event.payload[:error_message],
      )
    end

    def document_fetched(event)
      info log_entry(
        event: 'document_fetched',
        celex: event.payload[:celex],
        duration_ms: event.payload[:duration_ms],
      )
    end

    def fetch_failed(event)
      error log_entry(
        event: 'fetch_failed',
        url: event.payload[:url],
        error_class: event.payload[:error_class],
        error_message: event.payload[:error_message],
      )
    end

    def fetch_retry(event)
      warn log_entry(
        event: 'fetch_retry',
        url: event.payload[:url],
        attempt: event.payload[:attempt],
        max_attempts: event.payload[:max_attempts],
        error_class: event.payload[:error_class],
        error_message: event.payload[:error_message],
        error_code: event.payload[:error_code],
        backoff_seconds: event.payload[:backoff_seconds],
      )
    end

    def sparql_retry_attempt(event)
      warn log_entry(
        event: 'sparql_retry_attempt',
        attempt: event.payload[:attempt],
        max_attempts: event.payload[:max_attempts],
        error_class: event.payload[:error_class],
        error_message: event.payload[:error_message],
        error_code: event.payload[:error_code],
        count: event.payload[:count],
      )
    end

    def sparql_success_after_retry(event)
      info log_entry(
        event: 'sparql_success_after_retry',
        retry_attempts: event.payload[:retry_attempts],
        count: event.payload[:count],
      )
    end

    def document_imported(event)
      info log_entry(
        event: 'document_imported',
        celex: event.payload[:celex],
        duration_ms: event.payload[:duration_ms],
      )
    end

    def document_import_failed(event)
      error log_entry(
        event: 'document_import_failed',
        celex: event.payload[:celex],
        error_class: event.payload[:error_class],
        error_message: event.payload[:error_message],
      )
    end

    def duplicate_notification_attempt(event)
      warn log_entry(
        event: 'duplicate_notification_attempt',
        celex: event.payload[:celex],
        duplicate_attempt: event.payload[:duplicate_attempt],
        count: event.payload[:count],
      )
    end

    def reimport_failed(event)
      error log_entry(
        event: 'reimport_failed',
        version: event.payload[:version],
        error_class: event.payload[:error_class],
        error_message: event.payload[:error_message],
      )
    end

  private

    def log_entry(data)
      data.merge(service: 'xi_cn_importer', timestamp: Time.current.iso8601).to_json
    end
  end
end

XiCnImporter::Logger.attach_to :xi_cn_importer unless Rails.env.test?
