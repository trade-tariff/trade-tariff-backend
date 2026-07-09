module TariffSynchronizer
  include UpdateApplication
  include UpdateRollback
  include UpdateValidation

  class FailedUpdatesError < StandardError; end

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
