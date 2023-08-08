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
        rates_list = new
        rates_list.year = year
        rates_list.month = month
        rates_list.publication_date = exchange_rate_files(month, year).first.publication_date
        rates_list.exchange_rate_files = exchange_rate_files(month, year)
        rates_list.exchange_rates = exchange_rates(month, year)
        rates_list
      end

      def exchange_rate_files(month, year)
        files = ExchangeRateFile.where(month:, year:)

        ExchangeRateFile.wrap(files)
      end

      def exchange_rates(month, year)
        rates = ExchangeRateCurrencyRate.by_year_and_month(month, year)

        ExchangeRateCurrencyRate.wrap(rates)
      end
    end
  end
end
