module ExchangeRates
  class UploadMonthlyFileService
    def self.call(type)
      new(type).call
    end

    def initialize(type)
      @current_time = Time.zone.now
      @month = current_time.next_month.month
      @year = current_time.year
      @type = type
    end

    def call
      data_result = ::ExchangeRateCurrencyRate.for_month(month, year)

      if data_result.empty?
        raise DataNotFoundError, "No exchange rate data found for month #{month} and year #{year}."
      end

      case type
      when :csv
        upload_data(data_result, :csv, ExchangeRates::CreateCsvService)
      when :xml
        upload_data(data_result, :xml, ExchangeRates::CreateXmlService)
      else
        raise ArgumentError, "Invalid type: #{type}. Type must be :csv or :xml."
      end
    end

  private

    attr_reader :current_time, :month, :year, :type

    def upload_data(data_result, format, service_class)
      data_string = service_class.call(data_result)
      file_path = "data/exchange_rates/monthly_#{format}_#{year}-#{month}.#{format}"
      TariffSynchronizer::FileService.write_file(file_path, data_string)

      file_size = TariffSynchronizer::FileService.file_size(file_path)
      ExchangeRateFile.create(period_year: year, period_month: month, format:, file_size:, publication_date: current_time)

      info_message = "exchange_rates.monthly_#{format}-#{file_path}-size: #{data_string.size}"

      Rails.logger.info(info_message)
    end
  end

  class DataNotFoundError < StandardError; end
end
