class Appendix5aNotificationStatusCheckWorker
  include Sidekiq::Worker

  # Cap retries: Notify status checks must not use Sidekiq's default (25).
  sidekiq_options queue: :default, retry: 3

  FAILURE_STATUSES = [
    GovukNotifier::PERMANENT_FAILURE,
    GovukNotifier::TEMPORARY_FAILURE,
    GovukNotifier::TECHNICAL_FAILURE,
  ].freeze

  def perform(recipient_index, notification_uuid)
    return if notification_uuid.blank?

    status = GovukNotifier.new.get_email_status(notification_uuid)
    return unless FAILURE_STATUSES.include?(status)

    log_notification_event(event: 'delivery', state: 'failed', recipient_index:, notification_uuid:, status:)

    SlackNotifierService.call(
      "Appendix 5a: notification delivery failed for recipient index #{recipient_index} (status: #{status}) — check logs",
    )
  end

private

  def log_notification_event(event:, state:, **fields)
    payload = { event: "appendix5a_notification_#{event}", state:, **fields }
    message = "#{payload[:event]} #{state}: #{payload}"

    Rails.logger.error(message)
  end
end
