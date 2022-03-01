class CdsUpdatesWorker
  include Sidekiq::Worker

  TRY_AGAIN_IN = 20.minutes
  CUT_OFF_TIME = '07:30'.freeze

  sidekiq_options queue: :sync, retry: false

  def perform(check_for_todays_file = true)
    logger.info 'Running CdsUpdatesWorker'
    logger.info 'Downloading...'

    CdsSynchronizer.download

    if check_for_todays_file && still_time_to_reschedule? && todays_file_has_not_yet_arrived?
      self.class.perform_in(TRY_AGAIN_IN, true)
      logger.info "Daily file missing, retrying at #{TRY_AGAIN_IN.from_now}"
    else
      logger.info 'Applying...'

      CdsSynchronizer.apply(reindex_all_indexes: true)
    end
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
    !CdsSynchronizer.downloaded_todays_file?
  end
end
