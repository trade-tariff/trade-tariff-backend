module ExchangeRates
  class DataNotFoundError < StandardError; end

  class MonthlyExchangeRatesService
    def initialize(date, sample_date, download:)
      @date = date
      @sample_date = sample_date
      @download = download
    end

    def call
      ExchangeRates::UpdateCurrencyRatesService.new(date, sample_date, ExchangeRateCurrencyRate::MONTHLY_RATE_TYPE).call if download

      if rates.empty?
        raise DataNotFoundError, "No exchange rate data found for month #{date.month} and year #{date.year}."
      end

      ExchangeRates::UploadMonthlyFileService.new(
        rates,
        date,
        :monthly_csv,
      ).call

      ExchangeRates::UploadMonthlyFileService.new(
        rates,
        date,
        :monthly_xml,
      ).call

      ExchangeRates::UploadMonthlyFileService.new(
        rates,
        date,
        :monthly_csv_hmrc,
      ).call
    end

    def rates
      @rates ||= ::ExchangeRateCurrencyRate
        .for_month(date.month, date.year, ExchangeRateCurrencyRate::MONTHLY_RATE_TYPE)
        .sort_by { |rate| [rate.country_description, rate.currency_description] }
    end

    private

    attr_reader :date, :sample_date, :download
  end
end
