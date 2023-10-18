module ExchangeRates
  class UploadMonthlyFileService
    def initialize(rates, date, type)
      @rates = rates
      @date = date
      @type = type
    end

    def call
      rate_type = type == :spot_csv ? ExchangeRateCurrencyRate::SPOT_RATE_TYPE : ExchangeRateCurrencyRate::MONTHLY_RATE_TYPE

      rates = ::ExchangeRateCurrencyRate
        .for_month(month, year, rate_type)
        .sort_by { |rate| [rate.country_description, rate.currency_description] }

      if rates.empty?
        raise DataNotFoundError, "No exchange rate data found for month #{month} and year #{year}."
      end

      case type
      when :monthly_csv
        upload_data(:csv, ExchangeRates::CreateCsvService)
      when :monthly_xml
        upload_data(:xml, ExchangeRates::CreateXmlService)
      when :monthly_csv_hmrc
        upload_data(:csv, ExchangeRates::CreateCsvHmrcService)
      when :spot_csv
        upload_data(:csv, ExchangeRates::CreateCsvSpotService)
      else
        raise ArgumentError, "Invalid type: #{type}."
      end
    end

    private

    attr_reader :rates, :date, :type

    def upload_data(format, file_creation_service)
      exchange_rate_file = file_creation_service.call(rates)
      file_path = ExchangeRateFile.filepath_for(type, format, date.year, date.month)

      TariffSynchronizer::FileService.write_file(file_path, exchange_rate_file)

      file_size = TariffSynchronizer::FileService.file_size(file_path)
      ::ExchangeRateFile.create(
        period_year: date.year,
        period_month: date.month,
        format:,
        type:,
        file_size:,
        publication_date: date,
      )

      info_message = "Generated file name: #{file_path}, size: #{file_size}"

      Rails.logger.info(info_message)
    end

    def year
      @year ||= type == :spot_csv ? Time.zone.today.year : next_month_year(publication_date)
    end

    def month
      @month ||= type == :spot_csv ? Time.zone.today.month : next_month(publication_date)
    end
  end
end
