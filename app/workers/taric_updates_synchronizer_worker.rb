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
    unless TaricSynchronizer.apply # return if nothing changed
      emit_sync_run_completed(start_time)
      return
    end

    migrate_data if reapply_data_migrations

    MaterializeViewHelper.refresh_materialized_view

    ActiveSupport::Notifications.instrument(
      TradeTariffBackend::TariffUpdateEventListener::TARIFF_UPDATES_APPLIED,
      service: 'xi',
      oldest_pending_date: oldest_pending_date.iso8601,
    )

    emit_sync_run_completed(start_time)
  rescue StandardError => e
    TariffSynchronizer::Instrumentation.sync_run_failed(
      phase: 'sync',
      error_class: e.class.name,
      error_message: e.message,
    )
    raise
  ensure
    Thread.current[:tariff_sync_run_id] = nil
  end

private

  def emit_sync_run_completed(start_time)
    duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
    TariffSynchronizer::Instrumentation.sync_run_completed(duration_ms:)
  end

  def migrate_data
    logger.info 'Re-applying data migrations...'

    require 'data_migrator' unless defined?(DataMigrator)
    DataMigrator.migrate_up!(nil)
  end
end
