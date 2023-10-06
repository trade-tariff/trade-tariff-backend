module ExchangeRates
  class ExchangeRateCollection
    include ContentAddressableId

    content_addressable_fields :year, :month, :type

    attr_accessor :year,
                  :month,
                  :type,
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
        rates_list.type = type
        rates_list.exchange_rate_files = exchange_rate_files
        rates_list.exchange_rates = exchange_rates(month, year, type)
        rates_list
      end

      def exchange_rates(month, year, type)
        ExchangeRateCurrencyRate
          .for_month(month, year, type)
          .sort_by { |rate| [rate.country_description, rate.currency_description] }
      end
    end
  end
end
