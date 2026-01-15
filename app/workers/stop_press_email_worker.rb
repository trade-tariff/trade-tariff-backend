class StopPressEmailWorker
  include Sidekiq::Worker

  TEMPLATE_ID = '3295f0bf-c75f-4202-8dcf-703e4564b932'.freeze
  REPLY_TO_ID = '61e19d5e-4fae-4b7e-aa2e-cd05a87f4cf8'.freeze

  def perform(stop_press_id, user_id)
    stop_press = News::Item.find(id: stop_press_id)
    user = PublicUsers::User.active[id: user_id]

    return if stop_press.nil?
    return if user.nil?
    return unless user.email

    tracking_params = 'utm_source=private+beta&utm_medium=email&utm_campaign=stop+press+notification'

    personalisation = {
      stop_press_title: stop_press.title,
      stop_press_link: stop_press.public_url,
      subscription_reason: subscription_reason(stop_press, user),
      site_url: "#{URI.join(TradeTariffBackend.frontend_host, 'subscriptions/')}?#{tracking_params}",
      unsubscribe_url: "#{URI.join(TradeTariffBackend.frontend_host, 'subscriptions/unsubscribe/', user.stop_press_subscription)}?#{tracking_params}",
    }

    client.send_email(user.email, TEMPLATE_ID, personalisation, REPLY_TO_ID, nil)
  end

  def client
    @client ||= GovukNotifier.new
  end

  def subscription_reason(stop_press, user)
    return 'This is a non-chapter specific update from the UK Trade Tariff Service' if stop_press.chapters.blank?

    # Extract chapters from stop_press and filter by user's subscribed chapters if present
    chapters = stop_press.chapters.split(',').uniq.map(&:strip)
    chapters &= user.chapter_ids.split(',').uniq.map(&:strip) if user.chapter_ids.present?

    word_form = chapters.one? ? 'chapter' : 'chapters'
    "You have previously subscribed to receive updates about tariff #{word_form} - #{chapters.join(', ')}"
  end
end
