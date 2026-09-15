module TariffSynchronizer
  class BaseUpdateDownloader
    class << self
      def sync(initial_date:)
        applicable_download_date_range(initial_date:).each { |date| new(date).perform }
      end

      def applicable_download_date_range(initial_date:)
        download_start_date(initial_date:)..download_end_date
      end

    private

      def update_model
        raise NotImplementedError
      end

      def download_end_date
        Time.zone.today
      end

      def download_start_date(initial_date:)
        if update_model.pending_applied_or_failed.count.zero?
          initial_date
        else
          last_download = update_model.oldest_pending || update_model.most_recent_applied || update_model.most_recent_failed

          [last_download.issue_date, BaseUpdate::DOWNLOAD_FROM.ago.to_date].min
        end
      end
    end
  end
end
