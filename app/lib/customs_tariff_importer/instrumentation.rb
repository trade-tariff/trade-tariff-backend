require 'active_support/notifications'

module CustomsTariffImporter
  module Instrumentation
    module_function

    def instrument(event_name, payload = {}, &block)
      ActiveSupport::Notifications.instrument("#{event_name}.customs_tariff_importer", payload, &block)
    end

    def import_run_started
      instrument('import_run_started')
    end

    def import_run_completed(imported:, skipped:, failed:, duration_ms:)
      instrument('import_run_completed', imported:, skipped:, failed:, duration_ms:)
    end

    def import_run_failed(error_class:, error_message:)
      instrument('import_run_failed', error_class:, error_message:)
    end

    def fetch_started(url:)
      instrument('fetch_started', url:)
    end

    def document_fetched(version:, duration_ms:)
      instrument('document_fetched', version:, duration_ms:)
    end

    def fetch_failed(url:, error_class:, error_message:)
      instrument('fetch_failed', url:, error_class:, error_message:)
    end

    def parse_started(version:)
      instrument('parse_started', version:)
    end

    def document_parsed(version:, chapters:, sections:, rules:, duration_ms:)
      instrument('document_parsed', version:, chapters:, sections:, rules:, duration_ms:)
    end

    def parse_failed(version:, error_class:, error_message:)
      instrument('parse_failed', version:, error_class:, error_message:)
    end

    def document_skipped(version:, reason:)
      instrument('document_skipped', version:, reason:)
    end

    def document_imported(version:, duration_ms:)
      instrument('document_imported', version:, duration_ms:)
    end

    def document_import_failed(version:, error_class:, error_message:)
      instrument('document_import_failed', version:, error_class:, error_message:)
    end

    def status_changed(version:, from_status:, to_status:, whodunnit:)
      instrument('status_changed', version:, from_status:, to_status:, whodunnit:)
    end

    def section_note_updated(version:, section_id:, note_id:, whodunnit:)
      instrument('section_note_updated', version:, section_id:, note_id:, whodunnit:)
    end
  end
end
