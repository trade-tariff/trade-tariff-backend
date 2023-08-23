module ExchangeRates
  class Period
    attr_accessor :month, :year, :files

    def id
      "#{year}-#{month}-exchange_rate_period"
    end

    def file_ids
      files&.map(&:id)
    end

    class << self
      def wrap(months, year)
        months.map do |month|
          build(month, year)
        end
      end

      def build(month, year)
        period = new
        period.month = month
        period.year = year
        period.files = ::ExchangeRateFile.applicable_files_for(month, year)
        period
      end
    end
  end
end
