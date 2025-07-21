require 'logger'

module TariffSynchronizer
  class TariffLogger
    class << self
      # All pending updates applied
      def apply(update_names, import_warnings = [])
        Rails.logger.info('Finished applying updates')

        Mailer.applied(update_names, import_warnings).deliver_now
      end

      # Update failed to be applied
      def failed_update(exception:, update:, database_queries:)
        Rails.logger.error("Update failed: #{update}")

        Mailer.exception(
          exception,
          update,
          database_queries,
        ).deliver_now
      end

      # Update download failed
      def failed_download(exception:)
        Rails.logger.error "Download failed: #{exception.original}, url: #{exception.url}"

        Mailer.failed_download(exception.original, exception.url).deliver_now
      end

      # Exceeded retry count
      def retry_exceeded(date, url)
        Rails.logger.warn("Download retry count exceeded for #{url}")

        Mailer.retry_exceeded(date, url).deliver_now
      end

      # Update with blank content received
      def blank_update(date:, url:)
        Rails.logger.error("Blank update content received for #{date}: #{url}")

        Mailer.blank_update(url, date).deliver_now
      end

      # We missed {count} update files in a row
      # Might be okay for Taric. This is a precautionary measure
      def missing_updates(update_type:, count:)
        Rails.logger.warn("Missing #{count} updates in a row for #{update_type.to_s.upcase}")

        Mailer.missing_updates(event.payload[:count], event.payload[:update_type].to_s).deliver_now
      end
    end
  end
end
