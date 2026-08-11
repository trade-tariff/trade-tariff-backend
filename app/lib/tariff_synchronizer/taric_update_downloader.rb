module TariffSynchronizer
  # Download pending updates TARIC files
  class TaricUpdateDownloader
    DOWNLOAD_FROM = BaseUpdate::DOWNLOAD_FROM

    delegate :taric_query_url_template, :taric_update_url_template, :host, to: TaricSynchronizer

    class << self
      def download(initial_date: TaricSynchronizer.initial_update_date)
        unless sync_variables_set?
          Instrumentation.sync_run_failed(
            phase: 'download',
            error_class: 'ConfigurationError',
            error_message: 'Missing: Tariff sync environment variables: TARIFF_SYNC_USERNAME, TARIFF_SYNC_PASSWORD, TARIFF_SYNC_HOST and TARIFF_SYNC_EMAIL.',
          )
          return
        end

        TradeTariffBackend.with_redis_lock do
          Instrumentation.lock_acquired(phase: 'download')

          start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          if TradeTariffBackend.patch_broken_taric_downloads?
            sync_patched
          else
            sync(initial_date:)
          end

          duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
          Instrumentation.download_completed(
            duration_ms:,
            files_count: TaricUpdate.pending.count,
          )
        end
      end

      def sync(initial_date:)
        applicable_download_date_range(initial_date:).each { |issue_date| new(issue_date).perform }
      end

      def sync_patched
        update = applicable_update
        return if update.blank?

        TaricUpdateDownloaderPatched.new(update).perform
      end

      def applicable_download_date_range(initial_date:)
        download_start_date(initial_date:)..download_end_date
      end

      def applicable_update
        current_update = TaricUpdate.most_recent_pending || TaricUpdate.most_recent_applied

        return nil if current_update.blank?
        return nil unless TaricUpdate.correct_filename_sequence?

        current_update.next_update
      end

    private

      def sync_variables_set?
        TaricSynchronizer.username.present? &&
          TaricSynchronizer.password.present? &&
          TaricSynchronizer.host.present?
      end

      def download_end_date
        Time.zone.today
      end

      def download_start_date(initial_date:)
        if TaricUpdate.pending_applied_or_failed.count.zero?
          initial_date
        else
          last_download = TaricUpdate.oldest_pending || TaricUpdate.most_recent_applied || TaricUpdate.most_recent_failed

          [last_download.issue_date, DOWNLOAD_FROM.ago.to_date].min
        end
      end
    end

    attr_reader :date, :url

    def initialize(date)
      @date = date
      @url = date_api_url
    end

    def perform
      return if check_date_already_downloaded?

      Instrumentation.download_started(filename: "taric_check_#{date.iso8601}")
      send("create_record_for_#{response.state}_response")
    end

  private

    def response
      @response ||= TariffUpdatesRequester.perform(date_api_url)
    end

    def check_date_already_downloaded?
      TaricUpdate.find(issue_date: date).present?
    end

    def create_record_for_successful_response
      file_api_urls.each do |update|
        TariffDownloader.new(update[:filename], update[:url], date, TariffSynchronizer::TaricUpdate).perform
      end
    end

    def create_record_for_empty_response
      update_or_create(BaseUpdate::FAILED_STATE, missing_filename)
      TariffLogger.blank_update(date:, url:)
    end

    def create_record_for_exceeded_response
      update_or_create(BaseUpdate::FAILED_STATE, missing_filename)
      TariffLogger.retry_exceeded(date, url)
    end

    # We do not create records for missing updates (see dynamic send method in perform)
    def create_record_for_not_found_response; end

    def missing_filename
      "#{date}_taric"
    end

    def update_or_create(state, file_name)
      TariffSynchronizer::TaricUpdate.find_or_create(filename: file_name,
                                                     issue_date: date)
        .update(state:)
    end

    def date_api_url
      sprintf(taric_query_url_template, host:, date: date.strftime('%Y%m%d'))
    end

    def file_api_urls
      response
        .content
        .split("\n")
        .map { |name| name.gsub(/[^0-9a-zA-Z.]/i, '') }
        .map { |name| { filename: "#{date}_#{name}", url: sprintf(taric_update_url_template, host:, filename: name) } }
    end
  end
end
