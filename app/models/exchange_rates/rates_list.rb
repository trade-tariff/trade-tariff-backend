module ExchangeRates
  class RatesList
    attr_accessor :year,
                  :month,
                  :publication_date,
                  :exchange_rate_files,
                  :exchange_rates

    def id
      "#{year}-#{month}-exchange_rate_period"
    end

    def exchange_rate_file_ids
      exchange_rate_files.map(&:id)
    end

    def exchange_rate_ids
      exchange_rates.map(&:id)
    end

    class << self
      def build(month, year)
        exchange_rate_files = exchange_rate_files(month, year)

        rates_list = new
        rates_list.year = year
        rates_list.month = month
        rates_list.exchange_rate_files = exchange_rate_files
        rates_list.exchange_rates = exchange_rates(month, year)
        rates_list
      end

      def exchange_rate_files(period_month, period_year)
        ExchangeRateFile.where(period_month:, period_year:).all
      end

      def exchange_rates(month, year)
        rates = ExchangeRateCurrencyRate
          .by_month_and_year(month, year)
          .scheduled
          .eager(
            :exchange_rate_currency,
            :exchange_rate_countries,
          )
          .all

        Api::V2::ExchangeRates::CurrencyRatePresenter.wrap(rates, month, year)
      end
    end
  end
end
