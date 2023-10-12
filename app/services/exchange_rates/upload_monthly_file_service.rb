module ExchangeRates
  class UploadMonthlyFileService
    def initialize(rates, date, type)
      @rates = rates
      @date = date
      @type = type
    end

    def call
      case type
      when :monthly_csv
        upload_data(:csv, ExchangeRates::CreateCsvService)
      when :monthly_xml
        upload_data(:xml, ExchangeRates::CreateXmlService)
      when :monthly_csv_hmrc
        upload_data(:csv, ExchangeRates::CreateCsvHmrcService)
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

      Rails.logger.info("Generated file name: #{file_path}, size: #{file_size}")
    end
  end
end
