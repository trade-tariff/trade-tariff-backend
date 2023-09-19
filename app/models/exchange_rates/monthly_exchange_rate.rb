module ExchangeRates
  class MonthlyExchangeRate
    include ContentAddressableId

    content_addressable_fields :year, :month

    attr_accessor :year,
                  :month,
                  :publication_date,
                  :exchange_rate_files,
                  :exchange_rates

    def exchange_rate_file_ids
      exchange_rate_files.map(&:id)
    end

    def exchange_rate_ids
      exchange_rates.map(&:id)
    end

    class << self
      def build(month, year, type)
        exchange_rate_files = ExchangeRateFile.applicable_files_for(month, year, type)

        rates_list = new
        rates_list.year = year
        rates_list.month = month
        rates_list.exchange_rate_files = exchange_rate_files
        rates_list.exchange_rates = exchange_rates(month, year, type)
        rates_list
      end

      def exchange_rates(month, year, type)
        ExchangeRateCurrencyRate
          .by_month_and_year(month, year, type)
          .where(rate_type: type)
          .association_right_join(:exchange_rate_countries)
          .eager(:exchange_rate_currency)
          .order(:country)
          .all
      end
    end
  end
end
