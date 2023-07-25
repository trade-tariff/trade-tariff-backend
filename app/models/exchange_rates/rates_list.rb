module ExchangeRates
  class RatesList
    attr_accessor :year,
                  :month,
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
      def build(year)
        rates_list = new
        rates_list.year = year
        rates_list.month = month
        rates_list.exchange_rate_files = exchange_rate_files_for(month, year)
        rates_list.exchange_rates = exchange_rates_for(month, year)
        rates_list
      end

      def exchange_rate_files_for(month, year)
        files = ExchangeRateCurrencyRate.files_for_year_and_month(month, year)

        ExchangeRates::ExchangeRateFile.wrap(files)
      end

      def exchange_rates_for(month, year)
        rates = ExchangeRateCurrencyRate.by_year_and_month(month, year)

        ExchangeRates::ExchangeRate.wrap(rates)
      end
    end
  end
end
