module ExchangeRates
  class CreateCsvService
    HEADINGS = [
      'Country/Territories',
      'Currency',
      'Currency Code',
      'Currency Units per £1',
      'Start date',
      'End date',
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
        rate.rate,
        format_date(rate.validity_start_date),
        format_date(rate.validity_end_date),
      ]
    end

    def format_date(date)
      date.strftime('%d/%m/%Y')
    end
  end
end
