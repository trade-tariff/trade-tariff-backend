class TaricUpdatesSynchronizerWorker
  include Sidekiq::Worker
  include MaterializeViewHelper

  sidekiq_options queue: :sync, retry: false

  def perform(reapply_data_migrations = false)
    return unless TradeTariffBackend.xi?

    logger.info 'Running TaricUpdatesSynchronizerWorker'
    logger.info 'Downloading...'

    TaricSynchronizer.download
    logger.info 'Applying...'
    return unless TaricSynchronizer.apply # return if nothing changed

    migrate_data if reapply_data_migrations
    refresh_materialized_view

    Sidekiq::Client.enqueue(ClearInvalidSearchReferences)
    Sidekiq::Client.enqueue(TreeIntegrityCheckWorker)
    Sidekiq::Client.enqueue(ClearCacheWorker)

    # NOTE: Delay for 5 minutes as some of the category assessment queries rely on materialized views that need to have refreshed before we try to enumerate new category assessments.
    Sidekiq::Client.enqueue_in(5.minutes, GreenLanesUpdatesWorker)
  end

private

  def migrate_data
    logger.info 'Re-applying data migrations...'

    require 'data_migrator' unless defined?(DataMigrator)
    DataMigrator.migrate_up!(nil)
  end
end
