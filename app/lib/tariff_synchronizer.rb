# Redlock::LockAcquisitionError is defined inside redlock/client, which the gem
# autoloads. Require it so the rescue clauses below can always resolve it.
require 'redlock/client'

module TariffSynchronizer
  include Apply
  include Rollback

  class FailedUpdatesError < StandardError; end

  # Returned when another process already holds the sync lock. Callers must
  # branch on this rather than treating it as "nothing to apply".
  LOCK_UNAVAILABLE = :lock_unavailable

  delegate :instrument, :subscribe, to: ActiveSupport::Notifications

  cattr_accessor :root_path
  self.root_path = 'data'

  # Number of seconds to sleep between sync retries
  cattr_accessor :request_throttle
  self.request_throttle = TradeTariffBackend.request_throttle

  # Times to retry downloading update before giving up
  cattr_accessor :retry_count
  self.retry_count = TradeTariffBackend.tariff_sync_retry_count

  # Times to retry downloading update in case of serious problems (host resolution, ssl handshake, partial file) before giving up
  cattr_accessor :exception_retry_count
  self.exception_retry_count = TradeTariffBackend.exception_retry_count

  def apply_updates(update_type)
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

      applied_updates = apply_each_pending_day(update_type)

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
  rescue Redlock::LockAcquisitionError
    # A quorum of Redis servers could not be reached. That is an infrastructure
    # failure, not a concurrent run, so let it surface to Sidekiq and New Relic.
    raise
  rescue Redlock::LockError
    # Another process holds the sync lock and is doing the work. Legitimate, but
    # the caller must not report a completed run off the back of it.
    TariffSynchronizer::Instrumentation.lock_failed(phase: 'apply')
    LOCK_UNAVAILABLE
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
    SlackNotifierService.call(
      text: "Error #{exception.class}: #{exception.message}",
      channel: TradeTariffBackend.slack_failures_channel,
    )
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

  def update_type
    TradeTariffBackend.uk? ? CdsUpdate : TaricUpdate
  end

  def update_to
    ENV['DATE'] ? Date.parse(ENV['DATE']) : Time.zone.today
  end

  def sequel_models
    # Sequel::Model subclasses need to load into the ruby AST before they are visible
    # This only affects running this code in development mode which does not eager load in the normal course of events
    Rails.autoloaders.main.eager_load unless Rails.application.config.eager_load

    Sequel::Model.subclasses
  end
end
