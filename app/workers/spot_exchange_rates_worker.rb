class SpotExchangeRatesWorker
  include Sidekiq::Worker

  sidekiq_options retry: 1, retry_in: 1.hour

  def perform(sample_date = Time.zone.today.iso8601)
    sample_date = Date.parse(sample_date)

    return unless today_is_specific_date?(sample_date, 3, 31) || today_is_specific_date?(sample_date, 12, 31)

    ExchangeRates::SpotExchangeRatesService.new(sample_date, download: true).call

    notify
  end

  def notify
    message = 'Spot rates for the current month have been added and are accessible for viewing at /exchange_rates.'

    logger.info message

    SlackNotifierService.call(message)
  end

  def today_is_specific_date?(date, month, day)
    date.month == month && date.day == day
  end
end
