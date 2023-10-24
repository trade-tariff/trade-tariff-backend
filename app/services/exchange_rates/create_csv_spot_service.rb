module ExchangeRates
  class CreateCsvSpotService
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

        @data.each do |rate|
          csv << build_row(rate)
        end
      end
    end

    private

    def build_row(rate)
      [
        rate.country_description,
        rate.currency_description,
        rate.currency_code,
        sprintf('%.4f', 1 / rate.rate),
        rate.presented_rate,
      ]
    end

    def format_date(date)
      date.strftime('%d/%b/%Y')
    end
  end
end
