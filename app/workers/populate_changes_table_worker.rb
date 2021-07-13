class PopulateChangesTableWorker
  include Sidekiq::Worker

  sidekiq_options queue: :sync, retry: false

  def perform
    logger.info 'Running PopulateChangesTableWorker'
    logger.info 'Populating...'
    ChangesTablePopulator.generate
    ChangesTablePopulator.cleanup_outdated
  end
end
