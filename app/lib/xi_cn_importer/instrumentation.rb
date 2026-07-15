module XiCnImporter
  module Instrumentation
    NAMESPACE = 'xi_cn_importer'.freeze

    extend self

    def import_run_started
      instrument('import_run_started')
    end

    def import_run_completed(imported:, failed:, duration_ms:, review_backlog:)
      instrument('import_run_completed', imported:, failed:, duration_ms:, review_backlog:)
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

    def document_imported(celex:, duration_ms:)
      instrument('document_imported', celex:, duration_ms:)
    end

    def document_import_failed(celex:, error_class:, error_message:)
      instrument('document_import_failed', celex:, error_class:, error_message:)
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
