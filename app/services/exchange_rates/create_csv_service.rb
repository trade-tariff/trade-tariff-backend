module ExchangeRates
  class CreateCsvService
    attr_reader :data

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
        'Country/Territories',
        'Currency',
        'Currency Code',
        'Currency Units per £1',
        'Start date',
        'End date',
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
      # currency_country_data is an array with 2 elements
      # ['country_name', ExchangeRateCurrencyRate]

      country_name = currency_country_data.first
      currency_rate = currency_country_data.last

      [
        country_name,
        currency_rate.currency.try(:currency_description),
        currency_rate.currency_code,
        currency_rate.rate,
        format_date(currency_rate.validity_start_date),
        format_date(currency_rate.validity_end_date),
      ]
    end

    def order_data
      result = {}

      data.each do |currency_rate|
        currency_rate.countries.each do |country_data|
          result[country_data.country] = currency_rate
        end
      end

      result.sort
    end

    def format_date(date)
      date.strftime('%d/%m/%Y')
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
