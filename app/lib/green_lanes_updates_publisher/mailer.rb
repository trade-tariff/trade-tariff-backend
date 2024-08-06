require 'mailer_environment'

module GreenLanesUpdatesPublisher
  class Mailer < ApplicationMailer
    include MailerEnvironment

    default from: TradeTariffBackend.from_email,
            to: TradeTariffBackend.green_lanes_update_email

    def update(updates, date)
      @updated_date = date.to_fs(:govuk)
      @updates = updates

      mail subject: "#{subject_prefix(:info)} Green Lanes Updates"
    end
  end
end
