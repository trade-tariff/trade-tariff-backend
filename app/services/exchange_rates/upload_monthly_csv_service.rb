module ExchangeRates
  class UploadMonthlyCsvService
    delegate :instrument, to: ActiveSupport::Notifications

    def self.call
      new.call
    end

    def initialize
      @current_time = Time.zone.now
      @date_string = current_time.to_date.to_s
      @month = current_time.month
      @year = current_time.year
    end

    def call
      return unless penultimate_thursday?

      csv_string = ExchangeRates::CreateCsvService.call(data_result)

      TariffSynchronizer::FileService.write_file(file_path, csv_string)

      instrument('exchange_rates.monthly_csv',
                 date: date_string,
                 path: file_path,
                 size: csv_string.size)
    end

  private

    attr_reader :current_time, :month, :year, :date_string

    def data_result
      @data_result ||= ::ExchangeRateCurrencyRate.for_month(month, year)
    end

    def file_path
      "data/exchange_rates/monthly_csv_#{date_string}.csv"
    end

    def penultimate_thursday?
      return false unless current_time.thursday?
      return false unless current_time.month == 7.days.from_now.month
      return false unless current_time.month != 14.days.from_now.month

      true
    end
  end
end
