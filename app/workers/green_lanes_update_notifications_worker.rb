class GreenLanesUpdateNotificationsWorker
  include Sidekiq::Worker

  TRY_AGAIN_IN = 20.minutes
  CUT_OFF_TIME = '10:00'.freeze

  sidekiq_options queue: :sync, retry: false

  def perform
    return unless TradeTariffBackend.xi?

    date = Time.zone.today
    logger.info "Running GreenLanesUpdateNotificationsWorker: #{date}"

    logger.info 'Load updated data'
    updates = ::GreenLanesUpdatesPublisher::DataUpdatesFinder.new(date).call

    send_updates_email(updates, date)
    # add tracking record
  end

  private

  def send_updates_email(updates, date)
    ::GreenLanesUpdatesPublisher::Mailer.update(updates, date).deliver_now
  end
end
