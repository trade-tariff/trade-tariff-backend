class GreenLanesUpdatesWorker
  include Sidekiq::Worker

  sidekiq_options queue: :sync, retry: false

  def perform(date = Time.zone.today.iso8601)
    return unless TradeTariffBackend.xi?

    date = Date.parse(date)

    logger.info "Running GreenLanesUpdatesWorker: #{date}"

    logger.info 'Load updated data'

    (date..Time.zone.today).each do |day|
      updates = ::GreenLanesUpdatesPublisher::DataUpdatesFinder.new(day).call

      next unless updates.any?

      create_automated_ca(updates)

      if TradeTariffBackend.green_lanes_update_email.present?
        send_updates_email(updates, date)
      end

      create_notification(updates)
    end
  end

  private

  def create_automated_ca(updates)
    updates
      .select { |update| update.status == ::GreenLanes::UpdateNotification::NotificationStatus::CREATED }
      .each do |update|
        identified_ca = GreenLanes::IdentifiedMeasureTypeCategoryAssessment.where(measure_type_id: update.measure_type_id).first

        next unless identified_ca

        next if GreenLanes::CategoryAssessment[regulation_id: update.regulation_id,
                                               regulation_role: update.regulation_role,
                                               measure_type_id: update.measure_type_id]

        logger.info "Creating category assessment for #{update.measure_type_id}"

        assessment = GreenLanes::CategoryAssessment.new(regulation_id: update.regulation_id,
                                                        regulation_role: update.regulation_role,
                                                        measure_type_id: update.measure_type_id,
                                                        theme_id: identified_ca.theme_id)
        assessment.save(validate: true)
        update.status = ::GreenLanes::UpdateNotification::NotificationStatus::CA_CREATED
        update.theme_id = identified_ca.theme_id
        update.theme = ::GreenLanes::Theme.find(id: identified_ca.theme_id)&.to_s
    end
  end

  def send_updates_email(updates, date)
    logger.info 'Sending update emails'
    ::GreenLanesUpdatesPublisher::Mailer.update(updates, date).deliver_now
  end

  def create_notification(updates)
    logger.info 'Add tracking record'
    ::GreenLanesUpdatesPublisher::UpdateNotificationsCreator.new(updates).call
  end
end
