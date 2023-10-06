module ExchangeRates
  class CreateCsvHmrcService
    HEADINGS = %w[
      Period
      countryName
      countryCode
      currencyName
      currencyCode
      rateNew
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
        "#{format_date(rate.validity_start_date)} to #{format_date(rate.validity_end_date)}",
        rate.country_description,
        rate.country_code,
        rate.currency_description,
        rate.currency_code,
        rate.presented_rate,
      ]
    end

    def format_date(date)
      date.strftime('%d/%b/%Y')
    end
  end
end
