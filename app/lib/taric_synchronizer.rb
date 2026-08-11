class TaricSynchronizer
  extend TariffSynchronizer

  # 1 - does not raise an exception when record does not exist on TARIC DESTROY operation
  #   - does not raise an exception when record does not exist on TARIC UPDATE operation
  #   - creates new record when record does not exist on TARIC UPDATE operation
  cattr_accessor :ignore_presence_errors
  self.ignore_presence_errors = TradeTariffBackend.tariff_ignore_presence_errors

  cattr_accessor :username
  self.username = TradeTariffBackend.tariff_sync_username

  cattr_accessor :password
  self.password = TradeTariffBackend.tariff_sync_password

  cattr_accessor :host
  self.host = TradeTariffBackend.tariff_sync_host

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
    def update_type
      TariffSynchronizer::TaricUpdate
    end

    def download
      TariffSynchronizer::TaricUpdateDownloader.download(initial_date: initial_update_date)
    end

    def apply
      apply_updates(TaricUpdate)
    end

    # Restore database to specific date in the past
    #
    # NOTE: this does not remove records from initial seed
    def rollback(rollback_date, keep: false)
      rollback_updates(TaricUpdate, rollback_date, keep:)
    end
  end
end
