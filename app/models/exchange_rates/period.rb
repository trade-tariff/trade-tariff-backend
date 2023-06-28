module ExchangeRates
  class Period
    attr_accessor :month, :year, :files

    def id
      "#{year}-#{month}-exchange_rate_period"
    end

    class << self
      def build(months, year)
        months.map do |month|
          period = new
          period.month = month
          period.year = year
          period.files = files_for(month, year)
          period
        end
      end

      def files_for(_month, _year)
        []
      end
    end
  end
end
