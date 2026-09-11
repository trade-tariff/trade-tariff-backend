class MyCommoditiesEmailWorker
  include Sidekiq::Worker

  # Cap retries: Notify outages must not use Sidekiq's default (25) and crowd the default queue.
  sidekiq_options retry: 3

  # The date the orchestrator hands us, and that we parse back out again here.
  DATE_FORMAT = '%d/%m/%Y'.freeze

  # MyCommoditiesSubscriptionWorker stamps the date as sent as soon as it has enqueued us,
  # because enqueuing is all it can observe. When a child gives up for good, put the date
  # back into TariffChangesJobStatus.pending_emails so PopulateTariffChangesWorker redrives
  # it, rather than losing the day silently.
  sidekiq_retries_exhausted do |job, exception|
    _user_id, date, _changes_count = job['args']

    Sidekiq.logger.error("MyCommoditiesEmailWorker exhausted retries for #{date}: #{exception.message}")

    TariffChangesJobStatus.for_date(Date.strptime(date, DATE_FORMAT)).mark_emails_pending! if date.present?
  end

  TEMPLATE_ID = NOTIFY_CONFIGURATION.dig(:templates, :myott, :tariff_change)
  REPLY_TO_ID = NOTIFY_CONFIGURATION.dig(:reply_to, :tariff_management)

  def perform(user_id, date, changes_count)
    user = PublicUsers::User.active[id: user_id]

    return if date.nil?
    return if user.nil?
    return if user.email.blank?

    subscription = user.my_commodities_subscription
    return if subscription.nil?

    as_of_date = Date.parse(date).strftime('%Y-%m-%d')
    tracking_params = 'utm_source=private+beta&utm_medium=email&utm_campaign=commodity+watchlist'

    personalisation = {
      changes_count:,
      published_date: date,
      site_url: "#{URI.join(TradeTariffBackend.frontend_host, 'subscriptions/mycommodities')}?as_of=#{as_of_date}&#{tracking_params}",
      unsubscribe_url: "#{URI.join(TradeTariffBackend.frontend_host, 'subscriptions/unsubscribe/', subscription.uuid)}?#{tracking_params}",
    }

    response = client.send_email(user.email, TEMPLATE_ID, personalisation, REPLY_TO_ID, nil)
    client.schedule_status_check(user, response)
  end

  def client
    @client ||= GovukNotifier.new
  end
end
