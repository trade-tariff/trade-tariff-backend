class PopulateChangesTableWorker
  include Sidekiq::Worker

  sidekiq_options queue: :sync, retry: false

  def perform
    if TradeTariffBackend.process_extra_changes_for_tgp?
      ChangesTablePopulator.cleanup_outdated
      ChangesTablePopulator.populate
      logger.info 'Populating changes for TGP for 1-Jan-2022 & 1-Jan-2024, see env_var PROCESS_EXTRA_CHANGES_FOR_TGP'
      ChangesTablePopulator.populate(day: Time.zone.parse('2024-01-01'))
      ChangesTablePopulator.populate(day: Time.zone.parse('2022-01-01'))
    else
      ChangesTablePopulator.populate
      ChangesTablePopulator.cleanup_outdated
    end
  end
end
