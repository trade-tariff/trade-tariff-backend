class TaricSynchronizer
  extend TariffSynchronizer

  # 1 - does not raise an exception when record does not exist on TARIC DESTROY operation
  #   - does not raise an exception when record does not exist on TARIC UPDATE operation
  #   - creates new record when record does not exist on TARIC UPDATE operation
  cattr_accessor :ignore_presence_errors
  self.ignore_presence_errors = TradeTariffBackend.tariff_ignore_presence_errors

  cattr_accessor :username
  self.username = TradeTariffBackend.tariff_sync_username

  cattr_accessor :password
  self.password = TradeTariffBackend.tariff_sync_password

  cattr_accessor :host
  self.host = TradeTariffBackend.tariff_sync_host

  # Initial dump date + 1 day
  cattr_accessor :initial_update_date
  self.initial_update_date = Date.new(2012, 6, 6)

  # TARIC query url template
  cattr_accessor :taric_query_url_template
  self.taric_query_url_template = '%{host}/taric/TARIC3%{date}'

  # TARIC update url template
  cattr_accessor :taric_update_url_template
  self.taric_update_url_template = '%{host}/taric/%{filename}'

  class << self
    # Download pending updates for TARIC and CDS data
    # Gets latest downloaded file present in (inbox/failbox/processed) and tries
    # to download any further updates to current day.
    def download
      unless sync_variables_set?
        TariffSynchronizer::Instrumentation.sync_run_failed(
          phase: 'download',
          error_class: 'ConfigurationError',
          error_message: 'Missing: Tariff sync environment variables: TARIFF_SYNC_USERNAME, TARIFF_SYNC_PASSWORD, TARIFF_SYNC_HOST and TARIFF_SYNC_EMAIL.',
        )
        return
      end

      TradeTariffBackend.with_redis_lock do
        TariffSynchronizer::Instrumentation.lock_acquired(phase: 'download')

        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        begin
          TradeTariffBackend.patch_broken_taric_downloads? ? TariffSynchronizer::TaricUpdate.sync_patched : TariffSynchronizer::TaricUpdate.sync(initial_date: initial_update_date)
        rescue TariffSynchronizer::TariffUpdatesRequester::DownloadException => e
          TariffLogger.failed_download(exception: e)
          raise e.original
        end

        duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
        TariffSynchronizer::Instrumentation.download_completed(
          duration_ms:,
          files_count: TariffSynchronizer::TaricUpdate.pending.count,
        )
      end
    end

    def apply
      # The sync task is run on multiple machines to avoid more than one process
      # running the apply task it is wrapped with a redis lock
      TradeTariffBackend.with_redis_lock do
        TariffSynchronizer::Instrumentation.lock_acquired(phase: 'apply')

        applied_updates = []
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        check_tariff_updates_failures
        check_sequence

        # Updates could be modifying primary keys so unrestricted it for all models.
        sequel_models.each(&:unrestrict_primary_key)

        date_range = date_range_since_oldest_pending_update
        date_range.each do |day|
          applied_updates << perform_update(TaricUpdate, day)
        end

        applied_updates.flatten!

        if applied_updates.any? && BaseUpdate.pending_or_failed.none?
          duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
          TariffSynchronizer::Instrumentation.apply_completed(
            duration_ms:,
            files_applied: applied_updates.size,
          )
          TariffLogger.apply(applied_updates.map(&:filename))
          true
        end
      end
    rescue Redlock::LockError
      TariffSynchronizer::Instrumentation.lock_failed(phase: 'apply')
    end

    # Restore database to specific date in the past
    #
    # NOTE: this does not remove records from initial seed
    def rollback(rollback_date, keep: false)
      rollback_updates(TaricUpdate, rollback_date, keep:)
    end

    private

    def sync_variables_set?
      username.present? && password.present? && host.present?
    end
  end
end
