class MyCommoditiesEmailWorker
  include Sidekiq::Worker

  TEMPLATE_ID = '5db33f13-7235-4ed8-b704-e3fddc01ee09'.freeze
  REPLY_TO_ID = '61e19d5e-4fae-4b7e-aa2e-cd05a87f4cf8'.freeze

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

    client.send_email(user.email, TEMPLATE_ID, personalisation, REPLY_TO_ID, nil)
  end

  def client
    @client ||= GovukNotifier.new
  end
end
