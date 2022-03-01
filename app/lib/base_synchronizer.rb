class BaseSynchronizer
  class FailedUpdatesError < StandardError; end

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

  class << self
    private

    delegate :instrument, :subscribe, to: ActiveSupport::Notifications

    def perform_update(day)
      updates = update_type.pending_at(day).to_a
      updates.map do |update|
        instrument('perform_update.tariff_synchronizer',
                   filename: update.filename,
                   update_type:)

        TariffSynchronizer::BaseUpdateImporter.perform(update)
      end
      updates
    end

    def date_range_since_oldest_pending_update
      oldest_pending_update = TariffSynchronizer::BaseUpdate.oldest_pending
      return [] if oldest_pending_update.blank?

      (oldest_pending_update.issue_date..update_to)
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

    def check_sequence
      unless update_type.correct_filename_sequence?
        raise FailedUpdatesError, 'Wrong sequence between the pending and applied files. Check the admin updates UI.'
      end
    rescue FailedUpdatesError => e
      SlackNotifierService.new.call("Error #{e.class}: #{e.message}")

      raise
    end

    def check_tariff_updates_failures
      if TariffSynchronizer::BaseUpdate.failed.any?
        instrument('failed_updates_present.tariff_synchronizer',
                   file_names: TariffSynchronizer::BaseUpdate.failed.map(&:filename))
        raise FailedUpdatesError
      end
    rescue FailedUpdatesError => e
      SlackNotifierService.new.call("Error #{e.class}: #{e.message}")

      raise
    end
  end
end
