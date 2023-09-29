module ExchangeRates
  class Period
    attr_accessor :month, :year, :files, :has_exchange_rates

    def id
      "#{year}-#{month}-exchange_rate_period"
    end

    def file_ids
      files&.map(&:id)
    end

    class << self
      def wrap(months_and_years, type, has_exchange_rates)
        months_and_years.map do |month, year|
          build(month, year, type, has_exchange_rates)
        end
      end

      def build(month, year, type, has_exchange_rates)
        period = new
        period.month = month
        period.year = year
        period.files = ::ExchangeRateFile.applicable_files_for(month, year, type)
        period.has_exchange_rates = has_exchange_rates
        period
      end
    end
  end
end
