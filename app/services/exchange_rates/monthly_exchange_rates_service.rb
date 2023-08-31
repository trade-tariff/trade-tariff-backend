module ExchangeRates
  class MonthlyExchangeRatesService
    class << self
      def call
        return unless is_tomorrow_is_penultimate_thursday? && today_is_wednesday?

        ExchangeRates::UpdateCurrencyRatesService.new.call
        ExchangeRates::UploadMonthlyFileService.call(:monthly_csv)
        ExchangeRates::UploadMonthlyFileService.call(:monthly_xml)
        ExchangeRates::UploadMonthlyFileService.call(:monthly_csv_hmrc)

        notify
        email_files_to_hmrc
      end

      private

      def notify
        message = 'Exchange rates for the current month have been added and are accessible for viewing at /exchange_rates.'

        logger.info message

        SlackNotifierService.call(message)
      end

      def email_files_to_hmrc
        return if TradeTariffBackend.xi?

        ExchangeRatesMailer.monthly_files&.deliver_now
      end

      def is_tomorrow_is_penultimate_thursday?
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
