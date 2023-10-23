module ExchangeRates
  class AverageExchangeRatesService
    VALID_MONTHS = [4, 12].freeze
    VALID_DAY = 31

    class << self
      def call
        return unless valid_date

        avg_rates = create_average_rates
        log_to_slack
        build_average_rate_file(avg_rates)
      end

      private

      def build_average_rate_file(avg_rates)
        ExchangeRates::UploadFileService.new(
          avg_rates,
          Time.zone.today.iso8601,
          :average_csv,
        ).call
      end

      def valid_date
        return false unless Time.zone.today.day == VALID_DAY
        return false unless VALID_MONTHS.include?(Time.zone.today.month)
      end

      def create_average_rates
        currency_codes = ExchangeRateCountryCurrency.live_currency_codes

        currency_codes.map do |currency_code|
          next unless valid_average_rate(currency_code)

          avg_rate = valid_average_rate(currency_code)

          ExchangeRateCurrencyRate.create(
            currency_code:,
            validity_start_date: Time.zone.today.beginning_of_month,
            validity_end_date: nil,
            rate_type: ExchangeRateCurrencyRate::AVERAGE_RATE_TYPE,
            rate: avg_rate,
          )
        end
      end

      def valid_average_rate(currency_code)
        rates = ExchangeRateCurrencyRate.by_currency_and_last_year(currency_code)

        return unless rates.count >= 12
        return unless rates.first.validity_start_date.month == Time.zone.today.month
        return unless VALID_MONTHS.include?(rates.first.validity_start_date.month)

        rates.pluck(:rate).sum.fdiv(rates.size)
      end

      def log_to_slack
        message = 'Average exchange rates for the current period have been added and are accessible for viewing at /exchange_rates.'

        logger.info message

        SlackNotifierService.call(message)
      end
    end
  end
end
