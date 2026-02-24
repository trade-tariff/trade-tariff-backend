class TaricUpdatesSynchronizerWorker
  include Sidekiq::Worker

  sidekiq_options queue: :sync, retry: false

  def perform(reapply_data_migrations = false)
    return unless TradeTariffBackend.xi?

    Thread.current[:tariff_sync_run_id] = SecureRandom.uuid
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    oldest_pending_date = TariffSynchronizer::BaseUpdate.oldest_pending&.issue_date || Time.zone.today

    TariffSynchronizer::Instrumentation.sync_run_started(triggered_by: self.class.name)
    TariffSynchronizer::Instrumentation.download_started

    TaricSynchronizer.download

    TariffSynchronizer::Instrumentation.apply_started(pending_count: TariffSynchronizer::BaseUpdate.pending.count)
    return unless TaricSynchronizer.apply # return if nothing changed

    migrate_data if reapply_data_migrations

    MaterializeViewHelper.refresh_materialized_view

    # NOTE: Make sure caches have been refreshed including the CDN
    #       otherwise we serve up stale responses.
    #
    #       We let all of the other work complete off of the same queue first and whilst all items are dequeued in the correct order they have different runtimes so we add a further delay to be sure.
    Sidekiq::Client.enqueue_in(5.minutes, ClearCacheWorker)

    Sidekiq::Client.enqueue_in(5.minutes, ClearInvalidSearchReferences)
    Sidekiq::Client.enqueue_in(10.minutes, TreeIntegrityCheckWorker)
    Sidekiq::Client.enqueue_in(11.minutes, PopulateChangesTableWorker)

    # NOTE: This will create some category assessments.
    #       - Delay for 15 minutes as some of the category assessment queries rely on materialized views
    #       - Pass the oldest pending date to process all changes inclusive of the oldest pending update
    Sidekiq::Client.enqueue_in(15.minutes, GreenLanesUpdatesWorker, oldest_pending_date.iso8601)

    Sidekiq::Client.enqueue_in(20.minutes, ClearCacheWorker)

    duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
    TariffSynchronizer::Instrumentation.sync_run_completed(duration_ms:)
  ensure
    Thread.current[:tariff_sync_run_id] = nil
  end

private

  def migrate_data
    logger.info 'Re-applying data migrations...'

    require 'data_migrator' unless defined?(DataMigrator)
    DataMigrator.migrate_up!(nil)
  end
end
