module ExchangeRates
  class UploadMonthlyCsv
    attr_reader :date, :month, :year

    delegate :instrument, :subscribe, to: ActiveSupport::Notifications

    def self.call(date)
      new(date).call
    end

    def initialize(date)
      @date = date
      @month = date.month
      @year = date.year
    end

    def call
      return argument_error unless valid_date?

      csv_string = ExchangeRates::CreateCsv.call(data_result)

      TariffSynchronizer::FileService.write_file(file_path, csv_string)

      instrument('exchange_rates.monthly_csv',
                 date: current_date,
                 path: file_path,
                 size: csv_string.size)
    end

  private

    def data_result
      @data_result ||= ::ExchangeRateCurrencyRate.for_month(month, year)
    end

    def file_path
      "data/exchange_rates/monthly_csv_#{current_date}.csv"
    end

    def current_date
      @current_date ||= Date.current.to_s
    end

    def valid_date?
      return false unless date.is_a?(DateTime)

      true
    end

    def argument_error
      error_message = 'Argument error, invalid date, upload monthly CSV'
      Rails.logger.error(error_message)

      raise ArgumentError, error_message
    end
  end
end
