class CdsUpdatesSynchronizerWorker
  include Sidekiq::Worker
  include MaterializeViewHelper

  TRY_AGAIN_IN = 20.minutes
  CUT_OFF_TIME = '10:00'.freeze

  sidekiq_options queue: :sync, retry: false

  def perform(check_for_todays_file = true, reapply_data_migrations = false)
    return unless TradeTariffBackend.uk?

    logger.info 'Running CdsUpdatesSynchronizerWorker'
    logger.info 'Downloading...'

    CdsSynchronizer.download

    if check_for_todays_file &&
        todays_file_has_not_yet_arrived? &&
        attempt_reschedule!
      return
    end

    logger.info 'Applying...'
    return unless CdsSynchronizer.apply # return if nothing changed

    migrate_data if reapply_data_migrations
    refresh_materialized_view

    Sidekiq::Client.enqueue(ClearInvalidSearchReferences)
    Sidekiq::Client.enqueue(TreeIntegrityCheckWorker)
    Sidekiq::Client.enqueue(PopulateChangesTableWorker)
    Sidekiq::Client.enqueue_in(1.minute, ClearCacheWorker)
  rescue TariffSynchronizer::CdsUpdateDownloader::ListDownloadFailedError
    attempt_reschedule!
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

  def attempt_reschedule!
    if still_time_to_reschedule?
      self.class.perform_in(TRY_AGAIN_IN, true)
      logger.info "Daily file missing, retrying at #{TRY_AGAIN_IN.from_now}"
      true
    else
      SlackNotifierService.call \
        'Daily CDS file missing, max retry time passed - continuing without todays file'
      false
    end
  end
end
