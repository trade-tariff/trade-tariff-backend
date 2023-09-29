module ExchangeRates
  class PeriodList
    attr_accessor :year,
                  :exchange_rate_periods,
                  :exchange_rate_years,
                  :type

    include ContentAddressableId

    content_addressable_fields :year, :type

    def exchange_rate_year_ids
      exchange_rate_years.map(&:id)
    end

    def exchange_rate_period_ids
      exchange_rate_periods.map(&:id)
    end

    class << self
      def build(year, type)
        period_list = new
        period_list.year = year
        period_list.type = type
        period_list.exchange_rate_periods = exchange_rate_periods_for(year, type)
        period_list.exchange_rate_years = exchange_rate_years(type)
        period_list
      end

      def exchange_rate_periods_for(year, type)
        months = if type == 'average'
                   [3, 12]
                 else
                   ExchangeRateCurrencyRate.months_for_year(year, type)
                 end
        ExchangeRates::Period.wrap(months, year, type)
      end

      def exchange_rate_years(type)
        years = ExchangeRateCurrencyRate.all_years(type)

        ExchangeRates::PeriodYear.wrap(years)
      end
    end
  end
end
