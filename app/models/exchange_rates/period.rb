module ExchangeRates
  class Period
    attr_accessor :month, :year, :files, :has_exchange_rates

    def initialize(month:, year:, has_exchange_rates:, files:)
      @month = month
      @year = year
      @has_exchange_rates = has_exchange_rates
      @file = files
    end

    def id
      "#{year}-#{month}-exchange_rate_period"
    end

    def file_ids
      files&.map(&:id)
    end

    class << self
      def wrap(months_years_rates, type)
        months_years_rates.map { |m_y_r| build(m_y_r, type) }
      end

      def build(month_year_rate, type)
        month = month_year_rate[:month]
        year = month_year_rate[:year]

        new(month:,
            year:,
            has_exchange_rates: month_year_rate[:has_exchange_rates],
            files: ::ExchangeRateFile.applicable_files_for(month, year, type))
      end
    end
  end
end
