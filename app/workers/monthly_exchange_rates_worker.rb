class MonthlyExchangeRatesWorker
  include Sidekiq::Worker

  sidekiq_options retry: 1, retry_in: 1.hour

  def perform(sample_date = Time.zone.today.iso8601, force = false)
    sample_date = Date.parse(sample_date)
    date = sample_date.next_month

    return unless tomorrow_is_penultimate_thursday?(sample_date) || force

    ExchangeRates::MonthlyExchangeRatesService.new(date, sample_date, download: true).call

    notify
    email_files_to_hmrc(date)
  end

  def notify
    return unless ENV.fetch('ENVIRONMENT', '') == 'production'

    message = 'Exchange rates for the current month have been added and are accessible for viewing at /exchange_rates.'

    logger.info message

    SlackNotifierService.call(message)
  end

  def email_files_to_hmrc(date)
    return if TradeTariffBackend.xi?

    ExchangeRatesMailer.monthly_files(date)&.deliver_now
  end

  def tomorrow_is_penultimate_thursday?(sample_date)
    tomorrow = sample_date.tomorrow

    return false unless tomorrow.thursday?
    return false unless tomorrow.month == (sample_date + 8.days).month
    return false unless tomorrow.month != (sample_date + 15.days).month

    true
  end
end
