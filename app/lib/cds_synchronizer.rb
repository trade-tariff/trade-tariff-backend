class CdsSynchronizer < BaseSynchronizer
  # 1 - does not raise exception during record save
  #   - logs cds error with xml node, record errors and exception
  cattr_accessor :cds_logger_enabled
  self.cds_logger_enabled = (ENV['TARIFF_CDS_LOGGER'].to_i == 1)

  # set initial update date
  # Initial dump date + 1 day
  cattr_accessor :cds_initial_update_date
  self.cds_initial_update_date = Date.new(2020, 9, 1)

  cattr_accessor :update_type
  self.update_type = TariffSynchronizer::CdsUpdate

  class << self
    def download
      if ENV['HMRC_API_HOST'].blank? || ENV['HMRC_CLIENT_ID'].blank? || ENV['HMRC_CLIENT_SECRET'].blank?
        return instrument('config_error.tariff_synchronizer')
      end

      TradeTariffBackend.with_redis_lock do
        instrument('download.tariff_synchronizer') do
          update_type.sync
        rescue TariffUpdatesRequester::DownloadException => e
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

        subscribe 'apply.import_warnings' do |*args|
          event = ActiveSupport::Notifications::Event.new(*args)
          import_warnings << event.payload
        end

        date_range = date_range_since_oldest_pending_update
        date_range.each do |day|
          applied_updates << perform_update(day)
        end

        applied_updates.flatten!

        if applied_updates.any? && TariffSynchronizer::BaseUpdate.pending_or_failed.none?
          instrument('apply.tariff_synchronizer',
                     update_names: applied_updates.map(&:filename))

          Sidekiq::Client.enqueue(ClearCacheWorker) if reindex_all_indexes
        end
      end
    rescue Redlock::LockError
      instrument('apply_lock_error.tariff_synchronizer')
    end

    def rollback(rollback_date, keep: false)
      Rails.autoloaders.main.eager_load
      TradeTariffBackend.with_redis_lock do
        date = Date.parse(rollback_date.to_s)

        (date..Time.zone.today).to_a.reverse.each do |date_for_rollback|
          Sequel::Model.db.transaction do
            if keep
              update_type.applied_or_failed.where { issue_date > date_for_rollback }.each do |cds_update|
                # Delete actual data
                oplog_based_models.each do |model|
                  model.operation_klass.where('filename = ?', cds_update.filename).delete
                end

                instrument('rollback_update.tariff_synchronizer',
                           update_type: :cds,
                           filename: cds_update.filename)

                cds_update.mark_as_pending
                cds_update.clear_applied_at

                # delete cds errors
                cds_update.cds_errors_dataset.destroy
              end
            else
              update_type.where { issue_date > date_for_rollback }.each do |cds_update|
                # Delete actual data
                oplog_based_models.each do |model|
                  model.operation_klass.where('filename = ?', cds_update.filename).delete
                end

                instrument('rollback_update.tariff_synchronizer',
                           update_type: :cds,
                           filename: cds_update.filename)

                # delete cds errors
                cds_update.cds_errors_dataset.destroy

                cds_update.delete
              end
            end
          end
        end

        instrument('rollback.tariff_synchronizer', date:, keep:)
      end
    rescue Redlock::LockError
      instrument('rollback_lock_error.tariff_synchronizer', date: rollback_date, keep:)
    end

    delegate :downloaded_todays_file?, to: :update_type
  end
end
