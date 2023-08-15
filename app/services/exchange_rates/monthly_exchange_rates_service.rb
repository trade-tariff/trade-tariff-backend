module ExchangeRates
  class MonthlyExchangeRatesService
    class << self
      def call
        return unless tomorrow_is_penultimate_thursday? && today_is_wednesday?

        ExchangeRates::UpdateCurrencyRatesService.new.call
        ExchangeRates::UploadMonthlyFileService.call(:csv)
        ExchangeRates::UploadMonthlyFileService.call(:xml)

        notify
      end

      private

      def notify
        message = 'Exchange rates for the current month have been added and are accessible for viewing at /exchange_rates.'

        logger.info message

        SlackNotifierService.call(message)
      end

      def tomorrow_is_penultimate_thursday?
        tomorrow = Time.zone.now.tomorrow
        return false unless tomorrow.thursday?
        return false unless tomorrow.month == (7.days.from_now + 1.day).month
        return false unless tomorrow.month != (14.days.from_now + 1.day).month

        true
      end

      def today_is_wednesday?
        Time.zone.now.wednesday?
      end
    end
  end
end
