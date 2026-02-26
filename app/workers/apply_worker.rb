class ApplyWorker
  include Sidekiq::Worker

  sidekiq_options queue: :sync, retry: false

  def perform
    Thread.current[:tariff_sync_run_id] = SecureRandom.uuid
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    TariffSynchronizer::Instrumentation.sync_run_started(triggered_by: self.class.name)
    TariffSynchronizer::Instrumentation.apply_started(pending_count: TariffSynchronizer::BaseUpdate.pending.count)

    TradeTariffBackend.uk? ? CdsSynchronizer.apply : TaricSynchronizer.apply

    MaterializeViewHelper.refresh_materialized_view

    PopulateTariffChangesWorker.perform_async
    ClearCacheWorker.perform_async

    duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
    TariffSynchronizer::Instrumentation.sync_run_completed(duration_ms:)
  rescue StandardError => e
    TariffSynchronizer::Instrumentation.sync_run_failed(
      phase: 'apply',
      error_class: e.class.name,
      error_message: e.message,
    )
    raise
  ensure
    Thread.current[:tariff_sync_run_id] = nil
  end
end
