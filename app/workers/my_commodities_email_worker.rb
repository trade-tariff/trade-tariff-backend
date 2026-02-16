class MyCommoditiesEmailWorker
  include Sidekiq::Worker

  TEMPLATE_ID = NOTIFY_CONFIGURATION.dig(:templates, :myott, :tariff_change)
  REPLY_TO_ID = NOTIFY_CONFIGURATION.dig(:reply_to, :tariff_management)

  def perform(user_id, date, changes_count)
    user = PublicUsers::User.active[id: user_id]

    return if date.nil?
    return if user.nil?
    return if user.email.blank?
    return if user.deleted

    as_of_date = Date.parse(date).strftime('%Y-%m-%d')
    tracking_params = 'utm_source=private+beta&utm_medium=email&utm_campaign=commodity+watchlist'

    personalisation = {
      changes_count:,
      published_date: date,
      site_url: "#{URI.join(TradeTariffBackend.frontend_host, 'subscriptions/mycommodities')}?as_of=#{as_of_date}&#{tracking_params}",
      unsubscribe_url: "#{URI.join(TradeTariffBackend.frontend_host, 'subscriptions/unsubscribe/', user.my_commodities_subscription)}?#{tracking_params}",
    }

    response = client.send_email(user.email, TEMPLATE_ID, personalisation, REPLY_TO_ID, nil)
    client.schedule_status_check(user, response)
  end

  def client
    @client ||= GovukNotifier.new
  end
end
