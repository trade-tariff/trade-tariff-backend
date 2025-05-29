class GreenLanesUpdatesWorker
  include Sidekiq::Worker

  TRY_AGAIN_IN = 20.minutes
  CUT_OFF_TIME = '10:00'.freeze

  sidekiq_options queue: :sync, retry: false

  def perform
    return unless TradeTariffBackend.xi?

    date = Time.zone.today
    logger.info "Running GreenLanesUpdatesWorker: #{date}"

    logger.info 'Load updated data'
    updates = ::GreenLanesUpdatesPublisher::DataUpdatesFinder.new(date).call

    if updates.any?
      create_automated_ca(updates)

      if TradeTariffBackend.green_lanes_update_email.present?
        send_updates_email(updates, date)
      end
    end
  end

  private

  def create_automated_ca(updates)
    updates
      .select { |update| update.status == ::GreenLanes::UpdateNotification::NotificationStatus::CREATED }
      .each do |update|

      identified_ca = GreenLanes::IdentifiedMeasureTypeCategoryAssessment.where(measure_type_id: update[:measure_type_id]).first

      if identified_ca
        logger.info "Creating category assessment for #{update.measure_type_id}"

        assessment = GreenLanes::CategoryAssessment.new(regulation_id: update.regulation_id,
                                                        regulation_role: update.regulation_role,
                                                        measure_type_id: update.measure_type_id,
                                                        theme_id: identified_ca.theme_id)
        assessment.save(validate: true)
        identified_ca.status = ::GreenLanes::UpdateNotification::NotificationStatus::CA_CREATED
      end
    end
  end

  def send_updates_email(updates, date)
    logger.info 'Sending update emails'
    ::GreenLanesUpdatesPublisher::Mailer.update(updates, date).deliver_now

    logger.info 'Add tracking record'
    ::GreenLanesUpdatesPublisher::UpdateNotificationsCreator.new(updates).call
  end
end
