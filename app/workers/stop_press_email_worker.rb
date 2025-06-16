class StopPressEmailWorker
  include Sidekiq::Worker

  TEMPLATE_ID = 'a3b813e7-77ce-47c6-bdac-69ea24d7cdcd'.freeze

  def perform(stop_press_id, user_id)
    stop_press = News::Item.find(id: stop_press_id)
    user = PublicUsers::User.active[id: user_id]

    return if stop_press.nil?
    return if user.nil?
    return unless user.email

    personalisation = {
      stop_press_title: stop_press.title,
      stop_press_link: stop_press.public_url,
      subscription_reason: subscription_reason(stop_press, user),
      site_url: URI.join(TradeTariffBackend.frontend_host, 'subscriptions/').to_s,
      unsubscribe_url: URI.join(TradeTariffBackend.frontend_host, 'subscriptions/unsubscribe/', user.stop_press_subscription).to_s,
    }
    client.send_email(user.email, TEMPLATE_ID, personalisation)
  end

  def client
    @client ||= GovukNotifier.new
  end

  def subscription_reason(stop_press, user)
    if stop_press.chapters.blank?
      'This is a non-chapter specific update from the UK Trade Tariff Service'
    else
      chapters = if user.chapter_ids.empty?
                   stop_press.chapters
                 else
                   # Find common chapters between stop press and user subscriptions
                   (stop_press.chapters.split(',').map(&:strip) & user.chapter_ids.split(',').map(&:strip)).join(', ')
                 end
      "You have previously subscribed to receive updates about this tariff chapter - #{chapters}"
    end
  end
end
