class SpotExchangeRatesWorker
  include Sidekiq::Worker

  sidekiq_options retry: 1, retry_in: 1.hour

  def perform
    ExchangeRates::SpotExchangeRatesService.call
  end
end
