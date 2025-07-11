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
      return Rails.logger.error 'Missing: Tariff sync enviroment variables: HMRC_API_HOST, HMRC_CLIENT_ID and HMRC_CLIENT_SECRET.' unless sync_variables_set?

      TradeTariffBackend.with_redis_lock do
        begin
          TariffSynchronizer::CdsUpdate.sync(initial_date: initial_update_date)
        rescue TariffUpdatesRequester::DownloadException => e
          TariffLogger.failed_download(exception: e)
          raise e.original
        end
        Rails.logger.info 'Finished downloading updates'
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
          TariffLogger.apply(applied_updates.map(&:filename), import_warnings)
          true
        end
      end
    rescue Redlock::LockError
      Rails.logger.warn 'Failed to acquire Redis lock for update application'
    end

    def rollback(rollback_date, keep: false)
      Rails.autoloaders.main.eager_load

      TradeTariffBackend.with_redis_lock do
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

          update_filenames.each do |filename|
            Rails.logger.info "Rolling back CDS file: #{filename}"
          end

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

        Rails.logger.info "Rolled back to #{date}. Forced keeping records: #{keep}"
      end
    rescue Redlock::LockError
      Rails.logger.warn("Failed to acquire Redis lock for rollback to #{rollback_date}. Keep records: #{keep}")
    end

    def sync_variables_set?
      ENV['HMRC_API_HOST'].present? && ENV['HMRC_CLIENT_ID'].present? && ENV['HMRC_CLIENT_SECRET'].present?
    end
  end
end
