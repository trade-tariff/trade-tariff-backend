class WatchListInvitationEmailWorker
  include Sidekiq::Worker

  TEMPLATE_ID = '50b0bce2-3116-46dd-a2b2-2ba253534f01'.freeze
  REPLY_TO_ID = '61e19d5e-4fae-4b7e-aa2e-cd05a87f4cf8'.freeze

  def perform(user_id)
    user = PublicUsers::User[user_id]

    return if user&.email.blank?

    client.send_email(user.email, TEMPLATE_ID, nil, REPLY_TO_ID, nil)
  end

  def client
    @client ||= GovukNotifier.new
  end
end
