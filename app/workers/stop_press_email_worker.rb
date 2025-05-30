class StopPressEmailWorker
  include Sidekiq::Worker

  TEMPLATE_ID = 'a3b813e7-77ce-47c6-bdac-69ea24d7cdcd'.freeze

  def perform(stop_press_id, user_id)
    stop_press = News::Item.find(id: stop_press_id)
    user = PublicUsers::User.find(id: user_id)

    return if stop_press.nil?
    return unless user.email

    personalisation = {
      stop_press_title: stop_press.title,
      stop_press_link: stop_press.public_url,
      chapters: stop_press.chapters,
      site_url: URI.join(TradeTariffBackend.frontend_host, '/subscriptions').to_s,
      unsubscribe_url: '',
    }
    client.send_email(user.email, TEMPLATE_ID, personalisation)
  end

  def client
    @client ||= GovukNotifier.new
  end
end
