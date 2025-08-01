class TaricUpdatesSynchronizerWorker
  include Sidekiq::Worker
  include MaterializeViewHelper

  sidekiq_options queue: :sync, retry: false

  def perform(reapply_data_migrations = false)
    return unless TradeTariffBackend.xi?

    oldest_pending_date = TariffSynchronizer::BaseUpdate.oldest_pending&.issue_date || Time.zone.today

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

    # NOTE: This will create some category assessments.
    #       - Delay for 5 minutes as some of the category assessment queries rely on materialized views
    #       - Pass the oldest pending date to process all changes inclusive of the oldest pending update
    Sidekiq::Client.enqueue_in(5.minutes, GreenLanesUpdatesWorker, oldest_pending_date.iso8601)
  end

private

  def migrate_data
    logger.info 'Re-applying data migrations...'

    require 'data_migrator' unless defined?(DataMigrator)
    DataMigrator.migrate_up!(nil)
  end
end
