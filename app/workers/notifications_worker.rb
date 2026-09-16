class NotificationsWorker
  # The notification body lives only in Redis under a 1 hour TTL, and the API
  # has already answered 202 Accepted to a third party. A miss means we cannot
  # send that notification, so raise rather than complete: Sidekiq retries, and
  # a final failure reaches the death handler and New Relic.
  class MissingNotificationDataError < StandardError; end

  include Sidekiq::Worker

  # Cap retries: Notify outages must not use Sidekiq's default (25).
  sidekiq_options queue: :default, retry: 3

  def perform(notification_id)
    notification_data = notification_data(notification_id)

    if notification_data.nil?
      message = "Notification data not found for ID: #{notification_id}"

      Rails.logger.error(message)

      raise MissingNotificationDataError, message
    end

    notifier = GovukNotifier.new

    notifier.send_email(
      notification_data['email'],
      notification_data['template_id'],
      notification_data['personalisation'] || {},
      notification_data['email_reply_to_id'],
      notification_data['reference'],
    )

    TradeTariffBackend.redis.del("notification_#{notification_id}")
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
