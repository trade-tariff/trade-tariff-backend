class TaricSynchronizer < BaseSynchronizer
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

  cattr_accessor :update_type
  self.update_type = TariffSynchronizer::TaricUpdate

  class << self
    # Download pending updates for TARIC
    # Gets latest downloaded file present in (inbox/failbox/processed) and tries
    # to download any further updates to current day.
    def download
      return instrument('config_error.tariff_synchronizer') unless sync_variables_set?

      TradeTariffBackend.with_redis_lock do
        instrument('download.tariff_synchronizer') do
          TradeTariffBackend.patch_broken_taric_downloads? ? update_type.sync_patched : update_type.sync
        rescue TariffSynchronizer::TariffUpdatesRequester::DownloadException => e
          instrument('failed_download.tariff_synchronizer', exception: e)
          raise e.original
        end
      end
    end

    def apply(reindex_all_indexes: false)
      check_tariff_updates_failures
      check_sequence

      applied_updates = []
      import_warnings = []

      # The sync task is run on multiple machines to avoid more than on process
      # running the apply task it is wrapped with a redis lock
      TradeTariffBackend.with_redis_lock do
        # Updates could be modifying primary keys so unrestricted it for all models.
        sequel_models.each(&:unrestrict_primary_key)

        date_range = date_range_since_oldest_pending_update
        date_range.each do |day|
          applied_updates << perform_update(day)
        end

        applied_updates.flatten!

        if applied_updates.any? && TariffSynchronizer::BaseUpdate.pending_or_failed.none?
          instrument(
            'apply.tariff_synchronizer',
            update_names: applied_updates.map(&:filename),
            import_warnings:,
          )

          Sidekiq::Client.enqueue(ClearCacheWorker) if reindex_all_indexes
        end
      end
    rescue Redlock::LockError
      instrument('apply_lock_error.tariff_synchronizer')
    end

    # Restore database to specific date in the past
    #
    # NOTE: this does not remove records from initial seed
    def rollback(rollback_date, keep: false)
      TradeTariffBackend.with_redis_lock do
        date = Date.parse(rollback_date.to_s)

        (date..Time.zone.today).to_a.reverse.each do |date_for_rollback|
          Sequel::Model.db.transaction do
            # Delete actual data
            oplog_based_models.each do |model|
              model.operation_klass.where { operation_date > date_for_rollback }.delete
            end

            if keep
              # Rollback TARIC
              update_type.applied_or_failed.where { issue_date > date_for_rollback }.each do |taric_update|
                instrument('rollback_update.tariff_synchronizer',
                           update_type: :taric,
                           filename: taric_update.filename)

                taric_update.mark_as_pending
                taric_update.clear_applied_at

                # delete presence errors
                taric_update.presence_errors_dataset.destroy
              end
            else
              # Rollback TARIC
              update_type.where { issue_date > date_for_rollback }.each do |taric_update|
                instrument('rollback_update.tariff_synchronizer',
                           update_type: :taric,
                           filename: taric_update.filename)

                # delete presence errors
                taric_update.presence_errors_dataset.destroy
                taric_update.delete
              end
            end
          end
        end

        instrument('rollback.tariff_synchronizer', date:, keep:)
      end
    rescue Redlock::LockError
      instrument('rollback_lock_error.tariff_synchronizer', date: rollback_date, keep:)
    end

    def sync_variables_set?
      username.present? && password.present? && host.present?
    end
  end
end
