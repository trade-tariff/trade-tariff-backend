require 'mailer_environment'

module GreenLanesUpdatesPublisher
  class Mailer < ApplicationMailer
    include MailerEnvironment

    default from: TradeTariffBackend.from_email,
            to: TradeTariffBackend.green_lanes_update_email

    def update(_updates, date)
      @updated_date = date.to_fs(:govuk)

      mail subject: "#{subject_prefix(:info)} Green Lanes Updates"
    end
  end
end
