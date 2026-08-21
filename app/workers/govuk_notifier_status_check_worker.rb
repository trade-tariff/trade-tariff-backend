class GovukNotifierStatusCheckWorker
  include Sidekiq::Worker

  CHECK_DELAY = 10.minutes

  # Cap retries: Notify status checks must not use Sidekiq's default (25).
  sidekiq_options queue: :default, retry: 3

  def perform(user_id, notification_id)
    return if notification_id.blank?

    user = PublicUsers::User[id: user_id]

    return if user.nil?
    return if user.deleted

    status = Notifications::DeliveryStatusChecker.new(
      notification_id,
      pipeline: 'my_ott',
      identifier: user_id,
    ).call

    user.invalidate! if status == GovukNotifier::PERMANENT_FAILURE
  end
end
