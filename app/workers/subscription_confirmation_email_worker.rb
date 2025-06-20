class SubscriptionConfirmationEmailWorker
  include Sidekiq::Worker

  TEMPLATE_ID = '1f2eeee9-a7f1-46d0-a9ad-aa5059aea8a6'.freeze

  def perform(user_id)
    user = PublicUsers::User.active[id: user_id]

    return if user.nil?
    return unless user.email

    personalisation = {
      site_url: URI.join(TradeTariffBackend.frontend_host, 'subscriptions/').to_s,
      unsubscribe_url: URI.join(TradeTariffBackend.frontend_host, 'subscriptions/unsubscribe/', user.stop_press_subscription).to_s,
    }
    client.send_email(user.email, TEMPLATE_ID, personalisation)
  end

  def client
    @client ||= GovukNotifier.new
  end
end
