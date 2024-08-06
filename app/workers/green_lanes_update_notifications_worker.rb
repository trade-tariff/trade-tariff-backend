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

    if updates.any?
      send_updates_email(updates, date)
    end
  end

  private

  def send_updates_email(updates, date)
    logger.info 'Sending update emails'
    ::GreenLanesUpdatesPublisher::Mailer.update(updates, date).deliver_now

    logger.info 'Add tracking record'
    ::GreenLanesUpdatesPublisher::UpdateNotificationsCreator.new(updates).call
  end
end
