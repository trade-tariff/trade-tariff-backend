class CdsUpdatesSynchronizerWorker
  include Sidekiq::Worker

  sidekiq_options queue: :sync, retry: false

  def perform(check_for_todays_file = true, reapply_data_migrations = false, download_retry_count = 0)
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
    apply_result = CdsSynchronizer.apply

    # Another process holds the sync lock, so nothing was applied here. Reporting
    # a completed run would hide that from the sync log and the age metric.
    if apply_result == TariffSynchronizer::LOCK_UNAVAILABLE
      TariffSynchronizer::Instrumentation.sync_run_skipped(reason: 'lock_unavailable')
      return
    end

    unless apply_result # return if nothing changed
      # A quiet day (nothing pending, nothing failed) must still generate the
      # daily reports - see TaricUpdatesSynchronizerWorker; without this the
      # event-driven ReportWorker never runs on zero-apply days. Skipped when
      # updates are pending or failed so reports are never built from broken
      # data.
      ReportWorker.perform_in(15.minutes) if TariffSynchronizer::BaseUpdate.pending_or_failed.none?

      emit_sync_run_completed(start_time)
      return
    end

    migrate_data if reapply_data_migrations
    MaterializeViewHelper.refresh_materialized_view

    ActiveSupport::Notifications.instrument(
      TradeTariffBackend::TariffUpdateEventListener::TARIFF_UPDATES_APPLIED,
      service: 'uk',
    )

    emit_sync_run_completed(start_time)
  rescue TariffSynchronizer::TariffUpdatesRequester::RetriableDownloadError
    # Nothing left to reschedule means the download has given up for good. Ending
    # normally here would record a Sidekiq success and freeze UK tariff data at
    # yesterday's state with no failure alarm, so surface it.
    raise unless attempt_reschedule_download!(download_retry_count, check_for_todays_file, reapply_data_migrations)
  rescue TariffSynchronizer::CdsUpdateDownloader::ListDownloadFailedError => e
    TariffSynchronizer::Instrumentation.sync_run_failed(
      phase: 'download',
      error_class: e.class.name,
      error_message: e.message,
    )
    raise unless attempt_reschedule!
  ensure
    Thread.current[:tariff_sync_run_id] = nil
  end

private

  def cut_off_date_time
    @cut_off_date_time ||= begin
      hour, minute = TradeTariffBackend.cut_off_time.split(':', 2).map(&:to_i)

      Time.zone.now.beginning_of_day + hour.hours + minute.minutes
    end
  end

  def still_time_to_reschedule?
    Time.zone.now < cut_off_date_time
  end

  def todays_file_has_not_yet_arrived?
    !CdsSynchronizer.downloaded_todays_file?
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
      self.class.perform_in(TradeTariffBackend.try_again_in, true)
      TariffSynchronizer::Instrumentation.download_delayed(retry_at: TradeTariffBackend.try_again_in.from_now.iso8601)
      true
    else
      false
    end
  end

  # True when another attempt has been scheduled, false when the retry budget is
  # spent and the caller must surface the failure.
  def attempt_reschedule_download!(download_retry_count, check_for_todays_file, reapply_data_migrations)
    if download_retry_count >= TariffSynchronizer.retry_count
      TariffSynchronizer::Instrumentation.download_retry_exhausted(url: 'cds')
      return false
    end

    delay = TariffSynchronizer.request_throttle.seconds
    self.class.perform_in(delay, check_for_todays_file, reapply_data_migrations, download_retry_count + 1)
    TariffSynchronizer::Instrumentation.download_delayed(retry_at: delay.from_now.iso8601)
    true
  end
end
