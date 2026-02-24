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

  # Number of days to warn about missing updates after
  cattr_accessor :warning_day_count
  self.warning_day_count = 3

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
    if BaseUpdate.failed.any?
      Instrumentation.failed_updates_detected(filenames: BaseUpdate.failed.map(&:filename))
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
