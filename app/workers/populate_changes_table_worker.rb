class PopulateChangesTableWorker
  include Sidekiq::Worker

  sidekiq_options queue: :sync, retry: false

  def perform
    ChangesTablePopulator.populate
    if TradeTariffBackend.execute_clean_up_changes_table?
      ChangesTablePopulator.cleanup_outdated
    else
      logger.info 'Skipping cleanup of outdated changes, see env_var CLEAN_UP_CHANGES_TABLE'
    end
  end
end
