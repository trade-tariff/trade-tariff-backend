module ExchangeRates
  class UploadMonthlyFileService
    include ExchangeRatesHelper

    def self.call(type)
      new(type).call
    end

    def initialize(type)
      @publication_date = Time.zone.today
      @type = type
    end

    def call
      data_result = ::ExchangeRateCurrencyRate.for_month(month, year, ExchangeRateCurrencyRate::SCHEDULED_RATE_TYPE)

      if data_result.empty?
        raise DataNotFoundError, "No exchange rate data found for month #{month} and year #{year}."
      end

      case type
      when :monthly_csv
        upload_data(data_result, :csv, ExchangeRates::CreateCsvService)
      when :monthly_xml
        upload_data(data_result, :xml, ExchangeRates::CreateXmlService)
      when :monthly_csv_hmrc
        upload_data(data_result, :csv, ExchangeRates::CreateCsvHmrcService)
      else
        raise ArgumentError, "Invalid type: #{type}."
      end
    end

  private

    attr_reader :publication_date, :type

    def upload_data(data_result, format, service_class)
      data_string = service_class.call(data_result)
      file_path = ExchangeRateFile.filepath_for(type, format, year, month)

      TariffSynchronizer::FileService.write_file(file_path, data_string)

      file_size = TariffSynchronizer::FileService.file_size(file_path)
      ::ExchangeRateFile.create(
        period_year: year,
        period_month: month,
        format:,
        type:,
        file_size:,
        publication_date:,
      )

      info_message = "Generated file name: #{file_path}, size: #{file_size}"

      Rails.logger.info(info_message)
    end

    def year
      @year ||= next_month_year(publication_date)
    end

    def month
      @month ||= next_month(publication_date)
    end
  end

  class DataNotFoundError < StandardError; end
end
