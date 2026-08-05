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

    status = GovukNotifier.new.get_email_status(notification_id)

    if status == GovukNotifier::PERMANENT_FAILURE
      user.invalidate!
    end
  end
end
