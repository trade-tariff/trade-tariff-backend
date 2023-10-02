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
      def wrap(months_and_years, type)
        months_and_years.map do |month_and_year|
          build(
            month_and_year[:month_and_year],
            month_and_year[:has_exchange_rates],
            type,
          )
        end
      end

      def build(month_and_year, has_exchange_rates, type)
        month = month_and_year&.first
        year = month_and_year&.last

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
