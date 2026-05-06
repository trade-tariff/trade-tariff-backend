require 'active_support/log_subscriber'

module CustomsTariffImporter
  class Logger < ActiveSupport::LogSubscriber
    def import_run_started(_event)
      info log_entry(event: 'import_run_started')
    end

    def import_run_completed(event)
      info log_entry(
        event: 'import_run_completed',
        imported: event.payload[:imported],
        skipped: event.payload[:skipped],
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

    def fetch_started(event)
      info log_entry(event: 'fetch_started', url: event.payload[:url])
    end

    def document_fetched(event)
      info log_entry(
        event: 'document_fetched',
        version: event.payload[:version],
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

    def parse_started(event)
      info log_entry(event: 'parse_started', version: event.payload[:version])
    end

    def document_parsed(event)
      info log_entry(
        event: 'document_parsed',
        version: event.payload[:version],
        chapters: event.payload[:chapters],
        sections: event.payload[:sections],
        rules: event.payload[:rules],
        duration_ms: event.payload[:duration_ms],
      )
    end

    def parse_failed(event)
      error log_entry(
        event: 'parse_failed',
        version: event.payload[:version],
        error_class: event.payload[:error_class],
        error_message: event.payload[:error_message],
      )
    end

    def document_skipped(event)
      info log_entry(
        event: 'document_skipped',
        version: event.payload[:version],
        reason: event.payload[:reason],
      )
    end

    def document_imported(event)
      info log_entry(
        event: 'document_imported',
        version: event.payload[:version],
        duration_ms: event.payload[:duration_ms],
      )
    end

    def document_import_failed(event)
      error log_entry(
        event: 'document_import_failed',
        version: event.payload[:version],
        error_class: event.payload[:error_class],
        error_message: event.payload[:error_message],
      )
    end

    private

    def log_entry(data)
      data.merge(service: 'customs_tariff_importer', timestamp: Time.current.iso8601).to_json
    end
  end
end

CustomsTariffImporter::Logger.attach_to :customs_tariff_importer unless Rails.env.test?
