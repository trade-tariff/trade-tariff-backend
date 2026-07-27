class Appendix5aEmailWorker
  include Sidekiq::Worker

  TEMPLATE_ID = NOTIFY_CONFIGURATION.dig(:templates, :notifications, :appendix5a)

  def perform(email, new_count, changed_count, removed_count)
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
