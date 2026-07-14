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
        review_backlog: event.payload[:review_backlog],
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
