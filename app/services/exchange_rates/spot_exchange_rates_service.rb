module ExchangeRates
  class SpotExchangeRatesService
    class << self
      def call
        return unless today_is_specific_date?(Time.zone.now, 3, 31) || today_is_specific_date?(Time.zone.now, 12, 31)

        ExchangeRates::UpdateCurrencyRatesService.new(type: ExchangeRateCurrencyRate::SPOT_RATE_TYPE).call
        ExchangeRates::UploadMonthlyFileService.call(:spot_csv)

        notify
      end

      private

      def notify
        message = 'Spot rates for the current month have been added and are accessible for viewing at /exchange_rates.'

        logger.info message

        SlackNotifierService.call(message)
      end

      def today_is_specific_date?(date, month, day)
        date.month == month && date.day == day
      end
    end
  end
end
