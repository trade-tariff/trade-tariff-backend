class Appendix5aNotificationStatusCheckWorker
  include Sidekiq::Worker

  # Cap retries: Notify status checks must not use Sidekiq's default (25).
  sidekiq_options queue: :default, retry: 3

  def perform(recipient_index, notification_uuid)
    Notifications::DeliveryStatusChecker.new(notification_uuid, pipeline: 'appendix5a', identifier: recipient_index).call
  end
end
