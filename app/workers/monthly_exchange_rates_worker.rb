class MonthlyExchangeRatesWorker
  include Sidekiq::Worker

  sidekiq_options retry: false

  def perform
    ExchangeRates::UploadMonthlyFileService.call(:csv)
    ExchangeRates::UploadMonthlyFileService.call(:xml)
  end
end
