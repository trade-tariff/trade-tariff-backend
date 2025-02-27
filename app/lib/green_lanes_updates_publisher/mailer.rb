require 'mailer_environment'

module GreenLanesUpdatesPublisher
  class Mailer < ApplicationMailer
    include MailerEnvironment

    default from: TradeTariffBackend.from_email,
            to: TradeTariffBackend.green_lanes_update_email

    def update(updates, date)
      @updated_date = date.to_fs(:govuk)
      @updates = updates
      @include_measure_updates = TradeTariffBackend.green_lanes_notify_measure_updates
      @expired_count = @updates.count do |update|
        update.status == ::GreenLanes::UpdateNotification::NotificationStatus::EXPIRED
      end
      @updated_count = @updates.count do |update|
        update.status == ::GreenLanes::UpdateNotification::NotificationStatus::UPDATED
      end

      mail subject: "#{subject_prefix(:info)} Green Lanes Updates"
    end
  end
end
