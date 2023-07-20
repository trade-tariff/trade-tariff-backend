module ExchangeRates
  class UploadMonthlyFileService
    delegate :instrument, to: ActiveSupport::Notifications

    def self.call(type)
      new(type).call
    end

    def initialize(type)
      @current_time = Time.zone.now
      @month = current_time.month
      @year = current_time.year
      @type = type
    end

    def call
      return unless penultimate_thursday?

      data_result = ::ExchangeRateCurrencyRate.for_month(month, year)

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

      instrument("exchange_rates.monthly_#{format}".to_sym,
                 date: current_time.to_date.to_s,
                 path: file_path,
                 size: data_string.size)
    end

    def penultimate_thursday?
      return false unless current_time.thursday?
      return false unless current_time.month == 7.days.from_now.month
      return false unless current_time.month != 14.days.from_now.month

      true
    end
  end
end
