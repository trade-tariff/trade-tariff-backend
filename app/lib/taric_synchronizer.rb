class TaricSynchronizer
  extend TariffSynchronizer

  # 1 - does not raise an exception when record does not exist on TARIC DESTROY operation
  #   - does not raise an exception when record does not exist on TARIC UPDATE operation
  #   - creates new record when record does not exist on TARIC UPDATE operation
  cattr_accessor :ignore_presence_errors
  self.ignore_presence_errors = (ENV['TARIFF_IGNORE_PRESENCE_ERRORS'].to_i == 1)

  cattr_accessor :username
  self.username = ENV['TARIFF_SYNC_USERNAME']

  cattr_accessor :password
  self.password = ENV['TARIFF_SYNC_PASSWORD']

  cattr_accessor :host
  self.host = ENV['TARIFF_SYNC_HOST']

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
      return Rails.logger.error 'Missing: Tariff sync enviroment variables: TARIFF_SYNC_USERNAME, TARIFF_SYNC_PASSWORD, TARIFF_SYNC_HOST and TARIFF_SYNC_EMAIL.' unless sync_variables_set?

      TradeTariffBackend.with_redis_lock do
        begin
          TradeTariffBackend.patch_broken_taric_downloads? ? TariffSynchronizer::TaricUpdate.sync_patched : TariffSynchronizer::TaricUpdate.sync(initial_date: initial_update_date)
        rescue TariffSynchronizer::TariffUpdatesRequester::DownloadException => e
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

        date_range = date_range_since_oldest_pending_update
        date_range.each do |day|
          applied_updates << perform_update(TaricUpdate, day)
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

    # Restore database to specific date in the past
    #
    # NOTE: this does not remove records from initial seed
    def rollback(rollback_date, keep: false)
      TradeTariffBackend.with_redis_lock do
        date = Date.parse(rollback_date.to_s)

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
                Rails.logger.info "Rolling back Taric file: #{taric_update.filename}"

                taric_update.mark_as_pending
                taric_update.clear_applied_at

                # delete presence errors
                taric_update.presence_errors_dataset.destroy
              end
            else
              # Rollback TARIC
              TariffSynchronizer::TaricUpdate
                .where(Sequel.lit('issue_date > ?', date_for_rollback))
                .each do |taric_update|
                Rails.logger.info "Rolling back Taric file: #{taric_update.filename}"

                # delete presence errors
                taric_update.presence_errors_dataset.destroy
                taric_update.delete
              end
            end

            # Requeue data migrations
            # Rollback leaves 'date_for_rollback's data intact, it removes only
            # removes data for subsequent days - so look for migrations after
            # the end of the date_for_rollback day
            DataMigration.since(date_for_rollback.end_of_day).delete
          end
        end

        Rails.logger.info "Rolled back to #{date}. Forced keeping records: #{!!keep}"
      end
    rescue Redlock::LockError
      Rails.logger.warn("Failed to acquire Redis lock for rollback to #{rollback_date}. Keep records: #{keep}")
    end

    private

    def sync_variables_set?
      username.present? && password.present? && host.present?
    end
  end
end
