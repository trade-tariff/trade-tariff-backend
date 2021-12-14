module TariffSynchronizer
  class FailedUpdatesError < StandardError; end

  extend self

  # 1 - does not raise an exception when record does not exist on TARIC DESTROY operation
  #   - does not raise an exception when record does not exist on TARIC UPDATE operation
  #   - creates new record when record does not exist on TARIC UPDATE operation
  mattr_accessor :ignore_presence_errors
  self.ignore_presence_errors = (ENV['TARIFF_IGNORE_PRESENCE_ERRORS'].to_i == 1)

  # 1 - does not raise exception during record save
  #   - logs cds error with xml node, record errors and exception
  mattr_accessor :cds_logger_enabled
  self.cds_logger_enabled = (ENV['TARIFF_CDS_LOGGER'].to_i == 1)

  mattr_accessor :username
  self.username = ENV['TARIFF_SYNC_USERNAME']

  mattr_accessor :password
  self.password = ENV['TARIFF_SYNC_PASSWORD']

  mattr_accessor :host
  self.host = ENV['TARIFF_SYNC_HOST']

  mattr_accessor :root_path
  self.root_path = 'data'

  # Number of seconds to sleep between sync retries
  mattr_accessor :request_throttle
  self.request_throttle = 60

  # Initial dump date + 1 day
  mattr_accessor :taric_initial_update_date
  self.taric_initial_update_date = Date.new(2012, 6, 6)

  # set initial update date
  # Initial dump date + 1 day
  mattr_accessor :cds_initial_update_date
  self.cds_initial_update_date = Date.new(2020, 9, 1)

  # Times to retry downloading update before giving up
  mattr_accessor :retry_count
  self.retry_count = 20

  # Times to retry downloading update in case of serious problems (host resolution, ssl handshake, partial file) before giving up
  mattr_accessor :exception_retry_count
  self.exception_retry_count = 10

  # TARIC query url template
  mattr_accessor :taric_query_url_template
  self.taric_query_url_template = '%{host}/taric/TARIC3%{date}'

  # TARIC update url template
  mattr_accessor :taric_update_url_template
  self.taric_update_url_template = '%{host}/taric/%{filename}'

  # Number of days to warn about missing updates after
  mattr_accessor :warning_day_count
  self.warning_day_count = 3

  delegate :instrument, :subscribe, to: ActiveSupport::Notifications

  # Download pending updates for TARIC and CDS data
  # Gets latest downloaded file present in (inbox/failbox/processed) and tries
  # to download any further updates to current day.
  def download
    return instrument('config_error.tariff_synchronizer') unless sync_variables_set?

    TradeTariffBackend.with_redis_lock do
      instrument('download.tariff_synchronizer') do
        TaricUpdate.sync
      rescue TariffUpdatesRequester::DownloadException => e
        instrument('failed_download.tariff_synchronizer', exception: e)
        raise e.original
      end
    end
  end

  def download_cds
    if ENV['HMRC_API_HOST'].blank? || ENV['HMRC_CLIENT_ID'].blank? || ENV['HMRC_CLIENT_SECRET'].blank?
      return instrument('config_error.tariff_synchronizer')
    end

    TradeTariffBackend.with_redis_lock do
      instrument('download.tariff_synchronizer') do
        CdsUpdate.sync
      rescue TariffUpdatesRequester::DownloadException => e
        instrument('failed_download.tariff_synchronizer', exception: e)
        raise e.original
      end
    end
  end

  def apply(reindex_all_indexes: false)
    check_tariff_updates_failures

    applied_updates = []
    import_warnings = []

    # The sync task is run on multiple machines to avoid more than on process
    # running the apply task it is wrapped with a redis lock
    TradeTariffBackend.with_redis_lock do
      # Updates could be modifying primary keys so unrestricted it for all models.
      sequel_models.each(&:unrestrict_primary_key)

      date_range = date_range_since_last_pending_update
      date_range.each do |day|
        applied_updates << perform_update(TaricUpdate, day)
      end

      applied_updates.flatten!

      if applied_updates.any? && BaseUpdate.pending_or_failed.none?
        instrument(
          'apply.tariff_synchronizer',
          update_names: applied_updates.map(&:filename),
          import_warnings: import_warnings,
        )

        Sidekiq::Client.enqueue(ClearCacheWorker) if reindex_all_indexes
      end
    end
  rescue Redlock::LockError
    instrument('apply_lock_error.tariff_synchronizer')
  end

  def apply_cds(reindex_all_indexes: false)
    check_tariff_updates_failures

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

      date_range = date_range_since_last_pending_update
      date_range.each do |day|
        applied_updates << perform_update(CdsUpdate, day)
      end

      applied_updates.flatten!

      if applied_updates.any? && BaseUpdate.pending_or_failed.none?
        instrument('apply.tariff_synchronizer',
                   update_names: applied_updates.map(&:filename))

        Sidekiq::Client.enqueue(ClearCacheWorker) if reindex_all_indexes
      end
    end
  rescue Redlock::LockError
    instrument('apply_lock_error.tariff_synchronizer')
  end

  # Restore database to specific date in the past
  #
  # NOTE: this does not remove records from initial seed
  def rollback(rollback_date, keep = false)
    TradeTariffBackend.with_redis_lock do
      date = Date.parse(rollback_date.to_s)

      (date..Date.current).to_a.reverse.each do |date_for_rollback|
        Sequel::Model.db.transaction do
          # Delete actual data
          oplog_based_models.each do |model|
            model.operation_klass.where { operation_date > date_for_rollback }.delete
          end

          if keep
            # Rollback TARIC
            TariffSynchronizer::TaricUpdate.applied_or_failed.where { issue_date > date_for_rollback }.each do |taric_update|
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
            TariffSynchronizer::TaricUpdate.where { issue_date > date_for_rollback }.each do |taric_update|
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

      instrument('rollback.tariff_synchronizer', date: date, keep: keep)
    end
  rescue Redlock::LockError
    instrument('rollback_lock_error.tariff_synchronizer', date: rollback_date, keep: keep)
  end

  def rollback_cds(rollback_date, keep = false)
    Rails.autoloaders.main.eager_load
    TradeTariffBackend.with_redis_lock do
      date = Date.parse(rollback_date.to_s)

      (date..Date.current).to_a.reverse.each do |date_for_rollback|
        Sequel::Model.db.transaction do
          if keep
            TariffSynchronizer::CdsUpdate.applied_or_failed.where { issue_date > date_for_rollback }.each do |cds_update|
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
            TariffSynchronizer::CdsUpdate.where { issue_date > date_for_rollback }.each do |cds_update|
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

      instrument('rollback.tariff_synchronizer', date: date, keep: keep)
    end
  rescue Redlock::LockError
    instrument('rollback_lock_error.tariff_synchronizer', date: rollback_date, keep: keep)
  end

  def initial_update_date_for(update_type)
    send("#{update_type}_initial_update_date")
  end

  private

  def perform_update(update_type, day)
    updates = update_type.pending_at(day).to_a
    updates.map do |update|
      instrument('perform_update.tariff_synchronizer',
                 filename: update.filename,
                 update_type: update_type)

      BaseUpdateImporter.perform(update)
    end
    updates
  end

  def date_range_since_last_pending_update
    last_pending_update = BaseUpdate.last_pending
    return [] if last_pending_update.blank?

    (last_pending_update.issue_date..update_to)
  end

  def update_to
    ENV['DATE'] ? Date.parse(ENV['DATE']) : Date.current
  end

  def sync_variables_set?
    username.present? && password.present? && host.present?
  end

  def oplog_based_models
    sequel_models.select do |model|
      model.plugins.include?(Sequel::Plugins::Oplog)
    end
  end

  def sequel_models
    # Sequel::Model subclasses need to load into the ruby AST before they are visible
    # This only affects running this code in development mode which does not eager load in the normal course of events
    Rails.autoloaders.main.eager_load unless Rails.application.config.eager_load

    Sequel::Model.subclasses
  end

  def check_tariff_updates_failures
    if BaseUpdate.failed.any?
      instrument('failed_updates_present.tariff_synchronizer',
                 file_names: BaseUpdate.failed.map(&:filename))
      raise FailedUpdatesError
    end
  end
end
