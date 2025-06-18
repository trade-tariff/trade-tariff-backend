require_relative '../helpers/materialize_view_helper'
class TaricUpdatesSynchronizerWorker
  include Sidekiq::Worker
  include MaterializeViewHelper

  TRY_AGAIN_IN = 20.minutes
  CUT_OFF_TIME = '10:00'.freeze

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
    Sidekiq::Client.enqueue(InvalidateCacheWorker)
  end

private

  def migrate_data
    logger.info 'Re-applying data migrations...'

    require 'data_migrator' unless defined?(DataMigrator)
    DataMigrator.migrate_up!(nil)
  end
end
