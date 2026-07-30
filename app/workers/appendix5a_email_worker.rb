class Appendix5aEmailWorker
  include Sidekiq::Worker

  # Cap retries: Notify outages must not use Sidekiq's default (25) and crowd the default queue.
  sidekiq_options retry: 3

  TEMPLATE_ID = NOTIFY_CONFIGURATION.dig(:templates, :notifications, :appendix5a)

  def perform(recipient_index, new_count, changed_count, removed_count)
    email = TradeTariffBackend.cupid_team_to_emails[recipient_index]

    if email.blank?
      Rails.logger.error("appendix5a_notification_send skipped: recipient index #{recipient_index} no longer resolves to a configured email")
      return
    end

    personalisation = {
      new_count:,
      changed_count:,
      removed_count:,
      support_email: TradeTariffBackend.support_email,
    }

    notification = client.send_email(email, TEMPLATE_ID, personalisation, nil, nil)

    begin
      Appendix5aNotificationStatusCheckWorker.perform_in(
        GovukNotifierStatusCheckWorker::CHECK_DELAY,
        recipient_index,
        notification.notification_uuid,
      )
    rescue StandardError => e
      Rails.logger.error("appendix5a_notification_status_check_schedule_failed: recipient_index=#{recipient_index} #{e.class.name}: #{e.message}")
    end
  end

  def client
    @client ||= GovukNotifier.new
  end
end
