module ExchangeRates
  class DataNotFoundError < StandardError; end

  class SpotExchangeRatesService
    def initialize(sample_date, download:)
      @sample_date = sample_date
      @download = download
    end

    def call
      ExchangeRates::UpdateCurrencyRatesService.new(sample_date, sample_date, ExchangeRateCurrencyRate::SPOT_RATE_TYPE).call if download

      if rates.empty?
        raise DataNotFoundError, "No exchange rate data found for month #{sample_date.month} and year #{sample_date.year}."
      end

      ExchangeRates::UploadFileService.new(
        rates,
        sample_date,
        :spot_csv,
        sample_date,
      ).call
    end

    def rates
      @rates ||= ::ExchangeRateCurrencyRate
        .for_month(sample_date.month, sample_date.year, ExchangeRateCurrencyRate::SPOT_RATE_TYPE)
        .sort_by { |rate| [rate.country_description, rate.currency_description] }
    end

    private

    attr_reader :sample_date, :download
  end
end
