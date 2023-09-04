class MonthlyExchangeRatesWorker
  include Sidekiq::Worker

  sidekiq_options retry: 1, retry_in: 1.hour

  def perform
    ExchangeRates::MonthlyExchangeRatesService.call
  end
end
