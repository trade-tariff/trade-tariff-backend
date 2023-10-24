module ExchangeRates
  class CreateCsvAverageRatesService
    COUNTRY_INDEX = 0
    RATE_INDEX = 1

    HEADINGS = [
      'Country',
      'Unit Of Currency',
      'Currency Code',
      'Sterling value of Currency Unit £',
      'Currency Units per £1',
    ].freeze

    def self.call(data)
      new(data).call
    end

    def initialize(data)
      @data = data
    end

    def call
      CSV.generate do |csv|
        csv << HEADINGS

        # Data is in the format of { ExchangeRateCountryCurrency => avg_rate },{...}
        data.each do |hash|
          csv << build_row(hash)
        end
      end
    end

    private

    attr_reader :data

    def build_row(rate_hash)
      country = rate_hash[COUNTRY_INDEX]
      rate = rate_hash[RATE_INDEX]

      [
        country.country_description,
        country.currency_description,
        country.currency_code,
        sprintf('%.4f', 1 / rate),
        sprintf('%.4f', rate),
      ]
    end

    def format_date(date)
      date.strftime('%d/%b/%Y')
    end
  end
end
