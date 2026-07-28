class Appendix5aEmailWorker
  include Sidekiq::Worker

  TEMPLATE_ID = NOTIFY_CONFIGURATION.dig(:templates, :notifications, :appendix5a)

  def perform(recipient_index, new_count, changed_count, removed_count)
    email = TradeTariffBackend.cupid_team_to_emails[recipient_index]
    return if email.blank?

    personalisation = {
      new_count:,
      changed_count:,
      removed_count:,
      support_email: TradeTariffBackend.support_email,
    }

    client.send_email(email, TEMPLATE_ID, personalisation, nil, nil)
  end

  def client
    @client ||= GovukNotifier.new
  end
end
