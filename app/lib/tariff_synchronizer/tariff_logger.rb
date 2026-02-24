require 'logger'

module TariffSynchronizer
  class TariffLogger
    class << self
      # All pending updates applied
      def apply(update_names, import_warnings = [])
        Instrumentation.apply_completed(duration_ms: 0, files_applied: update_names.size)

        Mailer.applied(update_names, import_warnings).deliver_now
      end

      # Update failed to be applied
      def failed_update(exception:, update:, database_queries:)
        Instrumentation.file_import_failed(
          filename: update.to_s,
          error_class: exception.class.name,
          error_message: exception.message,
        )

        Mailer.exception(
          exception,
          update,
          database_queries,
        ).deliver_now
      end

      # Update download failed
      def failed_download(exception:)
        Instrumentation.download_failed(
          url: exception.url,
          error_type: exception.original.class.name,
        )

        Mailer.failed_download(exception.original, exception.url).deliver_now
      end

      # Exceeded retry count
      def retry_exceeded(date, url)
        Instrumentation.download_retry_exhausted(url:)

        Mailer.retry_exceeded(date, url).deliver_now
      end

      # Update with blank content received
      def blank_update(date:, url:)
        Instrumentation.download_failed(url:, error_type: 'blank_content')

        Mailer.blank_update(url, date).deliver_now
      end

      # We missed {count} update files in a row
      # Might be okay for Taric. This is a precautionary measure
      def missing_updates(update_type:, count:)
        Instrumentation.sync_run_failed(
          phase: 'download',
          error_class: 'MissingUpdates',
          error_message: "Missing #{count} updates in a row for #{update_type.to_s.upcase}",
        )

        Mailer.missing_updates(count, update_type.to_s).deliver_now
      end
    end
  end
end
