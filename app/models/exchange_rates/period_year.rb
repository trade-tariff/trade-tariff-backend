module ExchangeRates
  class PeriodYear
    attr_accessor :year

    def id
      "#{year}-exchange_rate_year"
    end

    def self.build(years)
      years.map do |year|
        period_year = new
        period_year.year = year
        period_year
      end
    end
  end
end
