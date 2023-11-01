module ExchangeRates
  class CreateAverageExchangeRatesService
    # Creates the average rates for countries that have had a live rate the last 12 months and upload the file

    VALID_MONTHS = [4, 12].freeze
    VALID_DAY = 31

    def self.call(selected_date:, force_run: false)
      new(force_run, selected_date).call
    end

    def initialize(force_run, selected_date)
      @force_run = force_run
      @selected_date = Date.parse(selected_date)
    end

    def call
      return argument_error unless valid_date? || force_run

      avg_rates = create_average_rates

      countries_and_rate = match_country_with_rates(avg_rates)
      upload_average_rate_file(countries_and_rate)
    end

    private

    attr_reader :force_run, :selected_date

    def match_country_with_rates(avg_rates)
      live_countries_last_twelve_months.each_with_object({}) do |country, h|
        avg_rate = avg_rates.find { |rate| rate.currency_code == country.currency_code }
                            .rate

        # { ExchangeRateCountryCurrency => avg_rate }
        h[country] = avg_rate
      end
    end

    def upload_average_rate_file(countries_and_rate)
      ExchangeRates::UploadFileService.new(
        countries_and_rate,
        selected_date,
        :average_csv,
      ).call
    end

    def valid_date?
      selected_date.day == VALID_DAY && VALID_MONTHS.include?(selected_date.month)
    end

    def create_average_rates
      live_countries_last_twelve_months.select_map(:currency_code).uniq.map do |currency_code|
        rates = ExchangeRateCurrencyRate.monthly_by_currency_last_year(currency_code, selected_date)

        next unless rates_valid?(rates)

        ExchangeRateCurrencyRate.create(
          currency_code:,
          validity_start_date: selected_date.beginning_of_month,
          validity_end_date: selected_date.end_of_month,
          rate_type: ExchangeRateCurrencyRate::AVERAGE_RATE_TYPE,
          rate: rates.pluck(:rate).sum.fdiv(rates.count),
        )
      end
    end

    def live_countries_last_twelve_months
      # This needs to be all countries that have had a rate for a currency last 12 months
      @live_countries_last_twelve_months ||= ExchangeRateCountryCurrency.live_last_twelve_months(selected_date)
    end

    def rates_valid?(rates)
      # Ensure the last month is not after the selected date
      return unless rates.last.validity_start_date <= selected_date

      # Ensure the first month is not greater than 12 months before selected date
      return unless rates.first.validity_end_date > selected_date - 12.months

      true
    end

    def argument_error
      error_message = "Argument error: #{selected_date} is not a valid date"

      Rails.logger.error(error_message)

      raise ArgumentError, error_message
    end
  end
end
