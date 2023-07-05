module ExchangeRates
  class PeriodYear
    attr_accessor :year

    def id
      "#{year}-exchange_rate_year"
    end

    class << self
      def wrap(years)
        years.map do |year|
          build(year)
        end
      end

      def build(year)
        period_year = new
        period_year.year = year
        period_year
      end
    end
  end
end
