class UpdatesSynchronizerWorker
  include Sidekiq::Worker

  TRY_AGAIN_IN = 20.minutes
  CUT_OFF_TIME = '07:30'.freeze

  sidekiq_options queue: :sync, retry: false

  def perform(check_for_todays_file = true, reapply_data_migrations = false)
    logger.info 'Running UpdatesSynchronizerWorker'
    logger.info 'Downloading...'

    if TradeTariffBackend.uk?
      TariffSynchronizer.download_cds

      if check_for_todays_file &&
          still_time_to_reschedule? &&
          todays_file_has_not_yet_arrived?

        self.class.perform_in(TRY_AGAIN_IN, true)
        logger.info "Daily file missing, retrying at #{TRY_AGAIN_IN.from_now}"
        return
      end

      logger.info 'Applying...'
      return unless TariffSynchronizer.apply_cds # return if nothing changed
    elsif TradeTariffBackend.xi?
      TariffSynchronizer.download
      logger.info 'Applying...'
      return unless TariffSynchronizer.apply # return if nothing changed
    end

    migrate_data if reapply_data_migrations

    Sidekiq::Client.enqueue(ClearCacheWorker)
    Sidekiq::Client.enqueue(ClearInvalidSearchReferences)
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
    !TariffSynchronizer.downloaded_todays_file_for_cds?
  end

  def migrate_data
    logger.info 'Re-applying data migrations...'

    require 'data_migrator' unless defined?(DataMigrator)
    DataMigrator.migrate_up!(nil)
  end
end
