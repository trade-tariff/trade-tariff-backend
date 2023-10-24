module ExchangeRates
  class AverageExchangeRatesService
    VALID_MONTHS = [4, 12].freeze
    VALID_DAY = 31

    def self.call(force_run)
      new.call(force_run)
    end

    def call(force_run)
      return argument_error unless valid_date || force_run

      avg_rates = create_average_rates

      countries_and_rate = match_country_with_rates(avg_rates)
      upload_average_rate_file(countries_and_rate)
    end

    private

    def match_country_with_rates(avg_rates)
      live_countries_last_twelve_months.each_with_object({}) do |country, h|
        # Need to ensure unique rates are being collected
        avg_rate = avg_rates
                    .select { |rate| rate.currency_code == country.currency_code }
                    .first
                    .rate

        # { ExchangeRateCountryCurrency => avg_rate }
        h[country] = avg_rate
      end
    end

    def upload_average_rate_file(countries_and_rate)
      ExchangeRates::UploadFileService.new(
        countries_and_rate,
        Time.zone.today,
        :average_csv,
      ).call
    end

    def valid_date
      return false unless Time.zone.today.day == VALID_DAY
      return false unless VALID_MONTHS.include?(Time.zone.today.month)

      true
    end

    def create_average_rates
      live_countries_last_twelve_months.select_map(:currency_code).uniq.map do |currency_code|
        avg_rate = valid_average_rate(currency_code)

        next unless avg_rate

        ExchangeRateCurrencyRate.create(
          currency_code:,
          validity_start_date: Time.zone.today.beginning_of_month,
          validity_end_date: Time.zone.today.end_of_month,
          rate_type: ExchangeRateCurrencyRate::AVERAGE_RATE_TYPE,
          rate: avg_rate,
        )
      end
    end

    def live_countries_last_twelve_months
      # This needs to be all countries that have had a rate for a currency last 12 months
      @live_countries_last_twelve_months ||= ExchangeRateCountryCurrency.live_last_twelve_months
    end

    def valid_average_rate(currency_code)
      rates = ExchangeRateCurrencyRate.monthly_by_currency_last_year(currency_code)

      # Ensure the last month is not after the current date
      return unless rates.last.validity_start_date <= Time.zone.today

      # Ensure the first month is not greater than 12 months ago
      return unless rates.first.validity_end_date > Time.zone.today - 12.months

      rates.pluck(:rate).sum.fdiv(rates.count)
    end

    def argument_error
      error_message = 'Argument error, invalid date, average exchange rate creation'

      Rails.logger.error(error_message)

      raise ArgumentError, error_message
    end
  end
end
