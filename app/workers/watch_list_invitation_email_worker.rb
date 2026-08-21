class WatchListInvitationEmailWorker
  include Sidekiq::Worker

  # Cap retries: Notify outages must not use Sidekiq's default (25) and crowd the default queue.
  sidekiq_options retry: 3

  TEMPLATE_ID = '50b0bce2-3116-46dd-a2b2-2ba253534f01'.freeze
  REPLY_TO_ID = 'a208a7ea-41d3-48dd-8bf7-24d4be1f4832'.freeze # Indu

  def perform(user_id)
    user = PublicUsers::User[user_id]

    return if user&.email.blank?

    client.send_email(user.email, TEMPLATE_ID, {}, REPLY_TO_ID, nil)
  end

  def client
    @client ||= GovukNotifier.new
  end
end
