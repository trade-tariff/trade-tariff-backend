class MonthlyExchangeRatesWorker
  include Sidekiq::Worker

  sidekiq_options retry: false

  def perform
    ExchangeRates::MonthlyExchangeRatesService.call
  end
end
