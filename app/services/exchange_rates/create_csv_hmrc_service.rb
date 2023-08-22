module ExchangeRates
  class CreateCsvHmrcService
    attr_reader :data

    COUNTRY_NAME_INDEX = 0
    CURRENCY_RATE_INDEX = 1

    def self.call(data)
      new(data).call
    end

    def initialize(data)
      @data = data
    end

    def call
      return argument_error unless valid_data?

      create_csv
    end

  private

    def headings
      [
        'Period',
        'countryName',
        'countryCode',
        'currencyName',
        'currencyCode',
        'rateNew',
      ]
    end

    def create_csv
      CSV.generate do |csv|
        csv << headings

        ordered_data = order_data

        ordered_data.each do |currency_country_data|
          csv << build_row(currency_country_data)
        end
      end
    end

    def build_row(currency_country_data)
      country_name = currency_country_data[COUNTRY_NAME_INDEX]
      currency_rate = currency_country_data[CURRENCY_RATE_INDEX]

      [
        "#{format_date(currency_rate.validity_start_date)} to #{format_date(currency_rate.validity_end_date)}",
        country_name,
        currency_rate.exchange_rate_countries.find { |country| country.country == country_name }.country_code,
        currency_rate.exchange_rate_currency.try(:currency_description),
        currency_rate.currency_code,
        sprintf('%.4f', currency_rate.rate),
      ]
    end

    def order_data
      result = {}

      data.each do |currency_rate|
        currency_rate.exchange_rate_countries.each do |country_data|
          result[country_data.country] = currency_rate
        end
      end

      result.sort
    end

    def format_date(date)
      date.strftime('%d/%b/%Y')
    end

    def valid_data?
      return false unless data.is_a?(Array)
      return false unless data.all? { |value| value.is_a?(ExchangeRateCurrencyRate) }

      true
    end

    def argument_error
      error_message = 'Argument error, invalid data, exchange rate monthly CSV'

      Rails.logger.error(error_message)

      raise ArgumentError, error_message
    end
  end
end
