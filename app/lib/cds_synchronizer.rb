class CdsSynchronizer
  extend TariffSynchronizer

  delegate :download_todays_file?, to: TariffSynchronizer::CdsUpdate

  # 1 - does not raise exception during record save
  #   - logs cds error with xml node, record errors and exception
  cattr_accessor :cds_logger_enabled
  self.cds_logger_enabled = (ENV['TARIFF_CDS_LOGGER'].to_i == 1)

  # set initial update date
  # Initial dump date + 1 day
  cattr_accessor :initial_update_date
  self.initial_update_date = Date.new(2020, 9, 1)

  class << self
    def download
      unless sync_variables_set?
        TariffSynchronizer::Instrumentation.sync_run_failed(
          phase: 'download',
          error_class: 'ConfigurationError',
          error_message: 'Missing: Tariff sync environment variables: HMRC_API_HOST, HMRC_CLIENT_ID and HMRC_CLIENT_SECRET.',
        )
        return
      end

      TradeTariffBackend.with_redis_lock do
        TariffSynchronizer::Instrumentation.lock_acquired(phase: 'download')

        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        begin
          TariffSynchronizer::CdsUpdate.sync(initial_date: initial_update_date)
        rescue TariffUpdatesRequester::DownloadException => e
          TariffLogger.failed_download(exception: e)
          raise e.original
        end

        duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
        TariffSynchronizer::Instrumentation.download_completed(
          duration_ms:,
          files_count: TariffSynchronizer::CdsUpdate.pending.count,
        )
      end
    end

    def apply
      check_tariff_updates_failures
      check_sequence

      applied_updates = []
      import_warnings = []

      # The sync task is run on multiple machines to avoid more than one process
      # running the apply task it is wrapped with a redis lock
      TradeTariffBackend.with_redis_lock do
        TariffSynchronizer::Instrumentation.lock_acquired(phase: 'apply')

        # Updates could be modifying primary keys so unrestricted it for all models.
        sequel_models.each(&:unrestrict_primary_key)

        subscribe 'apply.import_warnings' do |*args|
          event = ActiveSupport::Notifications::Event.new(*args)
          import_warnings << event.payload
        end

        date_range = date_range_since_oldest_pending_update
        date_range.each do |day|
          applied_updates << perform_update(CdsUpdate, day)
        end

        applied_updates.flatten!

        if applied_updates.any? && BaseUpdate.pending_or_failed.none?
          TariffSynchronizer::Instrumentation.apply_completed(
            duration_ms: 0,
            files_applied: applied_updates.size,
          )
          TariffLogger.apply(applied_updates.map(&:filename), import_warnings)
          true
        end
      end
    rescue Redlock::LockError
      TariffSynchronizer::Instrumentation.lock_failed(phase: 'apply')
    end

    def rollback(rollback_date, keep: false)
      Rails.autoloaders.main.eager_load

      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      TradeTariffBackend.with_redis_lock do
        TariffSynchronizer::Instrumentation.lock_acquired(phase: 'rollback')

        date = Date.parse(rollback_date.to_s)

        updates = TariffSynchronizer::CdsUpdate.where { issue_date > date }
        update_filenames = updates.pluck(:filename)

        Sequel::Model.db.transaction do
          # Delete actual data
          oplog_based_models.each do |model|
            model.operation_klass
                 .where(filename: update_filenames)
                 .delete
          end

          TariffChangesJobStatus.find(operation_date: date)&.mark_changes_pending!

          updates.each do |cds_update|
            cds_update.mark_as_pending
            cds_update.clear_applied_at
            cds_update.cds_errors_dataset.destroy
            cds_update.delete unless keep
          end

          # Look for migrations after the end of the
          # date_for_rollback day and remove them
          DataMigration.since(date.end_of_day).delete
        end

        duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
        TariffSynchronizer::Instrumentation.rollback_completed(
          rollback_date: date.iso8601,
          duration_ms:,
          files_count: update_filenames.size,
        )
      end
    rescue Redlock::LockError
      TariffSynchronizer::Instrumentation.lock_failed(phase: 'rollback')
    end

    def sync_variables_set?
      ENV['HMRC_API_HOST'].present? && ENV['HMRC_CLIENT_ID'].present? && ENV['HMRC_CLIENT_SECRET'].present?
    end
  end
end
