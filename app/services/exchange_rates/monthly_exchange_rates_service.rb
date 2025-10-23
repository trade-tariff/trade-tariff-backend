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

      ExchangeRates::UploadFileService.new(
        rates,
        date,
        :monthly_csv,
        sample_date,
      ).call

      ExchangeRates::UploadFileService.new(
        rates,
        date,
        :monthly_xml,
        sample_date,
      ).call

      ExchangeRates::UploadFileService.new(
        rates,
        date,
        :monthly_csv_hmrc,
        sample_date,
      ).call
    end

      # Moved this as couldnt find where rates is called outside and as a service should probably have only 1 call action
    private

    def rates
      @rates ||= ::ExchangeRateCurrencyRate
        .for_month(date.month, date.year, ExchangeRateCurrencyRate::MONTHLY_RATE_TYPE)
        .sort_by { |rate| [rate.country_description, rate.currency_description] }
    end

    attr_reader :date, :sample_date, :download
  end
end
