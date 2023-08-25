module ExchangeRates
  class PeriodList
    attr_accessor :year, :exchange_rate_periods, :exchange_rate_years

    include ContentAddressableId

    content_addressable_fields :year

    def exchange_rate_year_ids
      exchange_rate_years.map(&:id)
    end

    def exchange_rate_period_ids
      exchange_rate_periods.map(&:id)
    end

    class << self
      def build(year)
        period_list = new
        period_list.year = year
        period_list.exchange_rate_periods = exchange_rate_periods_for(year)
        period_list.exchange_rate_years = exchange_rate_years
        period_list
      end

      def exchange_rate_periods_for(year)
        months = ExchangeRateCurrencyRate.months_for_year(year)

        ExchangeRates::Period.wrap(months, year)
      end

      def exchange_rate_years
        years = ExchangeRateCurrencyRate.all_years

        ExchangeRates::PeriodYear.wrap(years)
      end
    end
  end
end
