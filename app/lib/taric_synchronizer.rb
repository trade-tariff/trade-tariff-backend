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
      check_tariff_updates_failures
      check_sequence

      applied_updates = []

      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      # The sync task is run on multiple machines to avoid more than one process
      # running the apply task it is wrapped with a redis lock
      TradeTariffBackend.with_redis_lock do
        TariffSynchronizer::Instrumentation.lock_acquired(phase: 'apply')

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
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      TradeTariffBackend.with_redis_lock do
        TariffSynchronizer::Instrumentation.lock_acquired(phase: 'rollback')

        date = Date.parse(rollback_date.to_s)
        files_count = 0

        (date..Time.zone.today).to_a.reverse_each do |date_for_rollback|
          Sequel::Model.db.transaction do
            # Delete actual data
            oplog_based_models.each do |model|
              model.operation_klass.where(Sequel.lit('operation_date > ?', date_for_rollback)).delete
            end

            if keep
              # Rollback TARIC
              TariffSynchronizer::TaricUpdate.applied_or_failed
                                             .where(Sequel.lit('issue_date > ?', date_for_rollback))
                                             .each do |taric_update|
                                               taric_update.mark_as_pending
                                               taric_update.clear_applied_at

                                               # delete presence errors
                                               taric_update.presence_errors_dataset.destroy
                                               files_count += 1
              end
            else
              # Rollback TARIC
              TariffSynchronizer::TaricUpdate
                .where(Sequel.lit('issue_date > ?', date_for_rollback))
                .each do |taric_update|
                  # delete presence errors
                  taric_update.presence_errors_dataset.destroy
                  taric_update.delete
                  files_count += 1
              end
            end

            # Requeue data migrations
            # Rollback leaves 'date_for_rollback's data intact, it removes only
            # removes data for subsequent days - so look for migrations after
            # the end of the date_for_rollback day
            DataMigration.since(date_for_rollback.end_of_day).delete
          end
        end

        duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
        TariffSynchronizer::Instrumentation.rollback_completed(
          rollback_date: date.iso8601,
          duration_ms:,
          files_count:,
        )
      end
    rescue Redlock::LockError
      TariffSynchronizer::Instrumentation.lock_failed(phase: 'rollback')
    end

    private

    def sync_variables_set?
      username.present? && password.present? && host.present?
    end
  end
end
