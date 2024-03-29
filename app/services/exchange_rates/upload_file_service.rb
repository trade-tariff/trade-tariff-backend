module ExchangeRates
  class UploadFileService
    def initialize(rates, date, type, sample_date)
      @rates = rates
      @date = date
      @type = type
      @sample_date = sample_date
    end

    def call
      case type
      when :monthly_csv
        upload_data(:csv, ExchangeRates::CreateCsvService)
      when :monthly_xml
        upload_data(:xml, ExchangeRates::CreateXmlService)
      when :monthly_csv_hmrc
        upload_data(:csv, ExchangeRates::CreateCsvHmrcService)
      when :spot_csv
        upload_data(:csv, ExchangeRates::CreateCsvSpotService)
      when :average_csv
        upload_data(:csv, ExchangeRates::CreateCsvAverageRatesService)
      end
    end

    private

    attr_reader :rates, :date, :type, :sample_date

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
        publication_date: sample_date,
      )

      Rails.logger.info("Generated file name: #{file_path}, size: #{file_size}")
    end
  end
end
