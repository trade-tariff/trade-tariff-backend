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
      def build(type, year = nil)
        period_list = new
        period_list.type = type
        period_list.year = year
        period_list.exchange_rate_periods = periods_for(type, year)
        period_list.exchange_rate_years = exchange_rate_years(type)
        period_list
      end

      private

      def periods_for(type, year)
        year = default_year(year, type)

        rate_months_and_years = ExchangeRateCurrencyRate.months_for(type, year).to_set
        file_months_and_years = ExchangeRateFile.months_for(type, year).to_set

        months_years_rates = (rate_months_and_years + file_months_and_years).uniq.sort_by { |m, y| [y, m] }
          .reverse
          .map do |month_and_year|
            {
              month: month_and_year[0],
              year: month_and_year[1],
              has_exchange_rates: rate_months_and_years.include?(month_and_year),
            }
          end

        ExchangeRates::Period.wrap(months_years_rates, type)
      end

      def exchange_rate_years(type)
        years = ExchangeRateCurrencyRate.all_years(type)
        years += ExchangeRateFile.all_years(type)
        years = years.uniq.sort.reverse

        ExchangeRates::PeriodYear.wrap(years)
      end

      # For monthly rates, we want to default to the latest year
      # All other types return all years worth of data
      def default_year(year, type)
        if type == ExchangeRateCurrencyRate::MONTHLY_RATE_TYPE
          (year.presence || ExchangeRateCurrencyRate.max_year(type)).to_i
        end
      end
    end
  end
end
