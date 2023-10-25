class AverageExchangeRatesWorker
  include Sidekiq::Worker

  sidekiq_options retry: 1, retry_in: 1.hour

  def perform
    ExchangeRates::AverageExchangeRatesService.call(force_run: false, selected_date: Time.zone.today.iso8601)

    notify
  end

  def notify
    message = 'Average exchange rates for the current period have been added and are accessible for viewing at /exchange_rates.'

    logger.info message

    SlackNotifierService.call(message)
  end
end
