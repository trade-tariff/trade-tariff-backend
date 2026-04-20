module TariffSynchronizer
  class FailedUpdatesError < StandardError; end

  delegate :instrument, :subscribe, to: ActiveSupport::Notifications

  cattr_accessor :root_path
  self.root_path = 'data'

  # Number of seconds to sleep between sync retries
  cattr_accessor :request_throttle
  self.request_throttle = 60

  # Times to retry downloading update before giving up
  cattr_accessor :retry_count
  self.retry_count = 20

  # Times to retry downloading update in case of serious problems (host resolution, ssl handshake, partial file) before giving up
  cattr_accessor :exception_retry_count
  self.exception_retry_count = 10

  def apply_updates(update_type)
    applied_updates = []
    import_warnings = []

    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    TradeTariffBackend.with_redis_lock do
      TariffSynchronizer::Instrumentation.lock_acquired(phase: 'apply')

      check_tariff_updates_failures
      check_sequence

      sequel_models.each(&:unrestrict_primary_key)

      subscribe 'apply.import_warnings' do |*args|
        event = ActiveSupport::Notifications::Event.new(*args)
        import_warnings << event.payload
      end

      date_range = date_range_since_oldest_pending_update
      date_range.each do |day|
        applied_updates << perform_update(update_type, day)
      end

      applied_updates.flatten!

      if applied_updates.any? && BaseUpdate.pending_or_failed.none?
        duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
        TariffSynchronizer::Instrumentation.apply_completed(
          duration_ms:,
          files_applied: applied_updates.size,
        )
        TariffLogger.apply(applied_updates.map(&:filename), import_warnings)
        true
      end
    end
  rescue Redlock::LockError
    TariffSynchronizer::Instrumentation.lock_failed(phase: 'apply')
  end

  def rollback_updates(update_type, rollback_date, keep: false)
    Rails.autoloaders.main.eager_load

    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    TradeTariffBackend.with_redis_lock do
      TariffSynchronizer::Instrumentation.lock_acquired(phase: 'rollback')

      date = Date.parse(rollback_date.to_s)
      updates = update_type.where { issue_date > date }
      update_filenames = updates.pluck(:filename)

      Sequel::Model.db.transaction do
        oplog_based_models.each do |model|
          model.operation_klass
               .where(filename: update_filenames)
               .delete
        end

        TariffChangesJobStatus.find(operation_date: date)&.mark_changes_pending!

        updates.each do |update|
          update.mark_as_pending
          update.clear_applied_at
          update.clear_errors
          update.delete unless keep
        end

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

  def date_range_since_oldest_pending_update
    oldest_pending_update = BaseUpdate.oldest_pending
    return [] if oldest_pending_update.blank?

    (oldest_pending_update.issue_date..update_to)
  end

  def perform_update(update_type, day)
    updates = update_type.pending_at(day).to_a
    updates.map do |update|
      Instrumentation.file_import_started(filename: update.filename)

      BaseUpdateImporter.perform(update)
    end
    updates
  end

  def check_tariff_updates_failures
    failed = update_type.failed
    if failed.any?
      Instrumentation.failed_updates_detected(filenames: failed.map(&:filename))
      raise FailedUpdatesError
    end
  rescue FailedUpdatesError => e
    notify_slack_app(e)

    raise
  end

  def notify_slack_app(exception)
    SlackNotifierService.call("Error #{exception.class}: #{exception.message}")
  end

  def check_sequence
    if update_type.correct_filename_sequence?
      Instrumentation.sequence_check_passed
    else
      Instrumentation.sequence_check_failed(
        details: 'Wrong sequence between the pending and applied files. Check the admin updates UI.',
      )
      raise FailedUpdatesError, 'Wrong sequence between the pending and applied files. Check the admin updates UI.'
    end
  rescue FailedUpdatesError => e
    notify_slack_app(e)

    raise
  end

  def initial_update_date_for(update_type)
    send("#{update_type}_initial_update_date")
  end

  def update_type
    TradeTariffBackend.uk? ? CdsUpdate : TaricUpdate
  end

  def update_to
    ENV['DATE'] ? Date.parse(ENV['DATE']) : Time.zone.today
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
end
