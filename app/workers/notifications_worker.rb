class NotificationsWorker
  include Sidekiq::Worker

  sidekiq_options queue: :default

  def perform(notification_id)
    notification_data = notification_data(notification_id)

    if notification_data.nil?
      Rails.logger.error("Notification data not found for ID: #{notification_id}")
    else
      notifier = GovukNotifier.new

      notifier.send_email(
        notification_data['email'],
        notification_data['template_id'],
        notification_data['personalisation'] || {},
        notification_data['email_reply_to_id'],
        notification_data['reference'],
      )

      TradeTariffBackend.redis.del("notification_#{notification_id}")
    end
  rescue StandardError => e
    Rails.logger.error("Failed to process notification with ID: #{notification_id}: #{e.message}\n#{e.backtrace.join("\n")}")
    raise
  end

  private

  def notification_data(notification_id)
    data = TradeTariffBackend.redis.get("notification_#{notification_id}")

    JSON.parse(data) if data.present?
  end
end
