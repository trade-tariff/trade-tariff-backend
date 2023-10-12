class MonthlyExchangeRatesWorker
  include Sidekiq::Worker

  sidekiq_options retry: 1, retry_in: 1.hour

  def perform
    return unless tomorrow_is_penultimate_thursday? && today_is_wednesday?

    date = Time.zone.today.next_month

    ExchangeRates::MonthlyExchangeRatesService.new(date, download: true).call

    notify
    email_files_to_hmrc(date)
  end

  def notify
    message = 'Exchange rates for the current month have been added and are accessible for viewing at /exchange_rates.'

    logger.info message

    SlackNotifierService.call(message)
  end

  def email_files_to_hmrc(date)
    return if TradeTariffBackend.xi?

    ExchangeRatesMailer.monthly_files(date)&.deliver_now
  end

  def tomorrow_is_penultimate_thursday?
    tomorrow = Time.zone.now.tomorrow

    return false unless tomorrow.thursday?
    return false unless tomorrow.month == (7.days.from_now + 1.day).month
    return false unless tomorrow.month != (14.days.from_now + 1.day).month

    true
  end

  def today_is_wednesday?
    Time.zone.now.wednesday?
  end
end
