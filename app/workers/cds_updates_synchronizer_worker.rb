class CdsUpdatesSynchronizerWorker
  include Sidekiq::Worker

  TRY_AGAIN_IN = 20.minutes
  CUT_OFF_TIME = '10:00'.freeze

  sidekiq_options queue: :sync, retry: false

  def perform(check_for_todays_file = true, reapply_data_migrations = false)
    return unless TradeTariffBackend.uk?

    Thread.current[:tariff_sync_run_id] = SecureRandom.uuid
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    TariffSynchronizer::Instrumentation.sync_run_started(triggered_by: self.class.name)
    TariffSynchronizer::Instrumentation.download_started

    CdsSynchronizer.download

    if check_for_todays_file &&
        todays_file_has_not_yet_arrived? &&
        attempt_reschedule!
      emit_sync_run_completed(start_time)
      return
    end

    TariffSynchronizer::Instrumentation.apply_started(pending_count: TariffSynchronizer::BaseUpdate.pending.count)
    unless CdsSynchronizer.apply # return if nothing changed
      emit_sync_run_completed(start_time)
      return
    end

    migrate_data if reapply_data_migrations
    MaterializeViewHelper.refresh_materialized_view

    Sidekiq::Client.enqueue_in(5.minutes, ClearCacheWorker)
    Sidekiq::Client.enqueue_in(5.minutes, ClearInvalidSearchReferences)
    Sidekiq::Client.enqueue_in(10.minutes, TreeIntegrityCheckWorker)
    Sidekiq::Client.enqueue_in(11.minutes, PopulateChangesTableWorker)
    Sidekiq::Client.enqueue_in(12.minutes, PopulateTariffChangesWorker)
    Sidekiq::Client.enqueue_in(15.minutes, ClearCacheWorker)

    emit_sync_run_completed(start_time)
  rescue TariffSynchronizer::CdsUpdateDownloader::ListDownloadFailedError => e
    TariffSynchronizer::Instrumentation.sync_run_failed(
      phase: 'download',
      error_class: e.class.name,
      error_message: e.message,
    )
    attempt_reschedule!
  ensure
    Thread.current[:tariff_sync_run_id] = nil
  end

private

  def cut_off_date_time
    @cut_off_date_time ||= begin
      hour, minute = CUT_OFF_TIME.split(':', 2).map(&:to_i)

      Time.zone.now.beginning_of_day + hour.hours + minute.minutes
    end
  end

  def still_time_to_reschedule?
    Time.zone.now < cut_off_date_time
  end

  def todays_file_has_not_yet_arrived?
    !TariffSynchronizer::CdsUpdate.downloaded_todays_file?
  end

  def migrate_data
    logger.info 'Re-applying data migrations...'

    require 'data_migrator' unless defined?(DataMigrator)
    DataMigrator.migrate_up!(nil)
  end

  def emit_sync_run_completed(start_time)
    duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
    TariffSynchronizer::Instrumentation.sync_run_completed(duration_ms:)
  end

  def attempt_reschedule!
    if still_time_to_reschedule?
      self.class.perform_in(TRY_AGAIN_IN, true)
      TariffSynchronizer::Instrumentation.download_delayed(retry_at: TRY_AGAIN_IN.from_now.iso8601)
      true
    else
      SlackNotifierService.call \
        'Daily CDS file missing, max retry time passed - continuing without todays file'
      false
    end
  end
end
