module ExchangeRates
  class CreateAllExchangeRateFilesService
    def call
      ExchangeRateFile
        .where(type: %w[monthly_csv_hmrc monthly_csv monthly_xml])
        .delete

      dates.each do |date|
        ExchangeRates::MonthlyExchangeRatesService.new(date, download: false).call
      end
    end

    def dates
      @dates ||= ExchangeRateCurrencyRate
        .by_type(ExchangeRateCurrencyRate::MONTHLY_RATE_TYPE)
        .distinct(:validity_start_date)
        .order(:validity_start_date)
        .select_map(:validity_start_date)
    end
  end
end
