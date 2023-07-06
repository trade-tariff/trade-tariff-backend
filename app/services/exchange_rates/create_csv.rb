module ExchangeRates
  class CreateCsv
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
        csv << [headings]
        data.each do |currency_rate|
          csv << build_row(currency_rate)
        end
      end
    end

    def build_row(currency_rate)
      currency_code = currency_rate.currency_code

      exchange_rate_currency = ExchangeRateCurrency.find(currency_code: currency_rate.currency_code)
      territories = ExchangeRateCountry.where(currency_code: currency_rate.currency_code).pluck(:country_code)

      [
        territories,
        exchange_rate_currency.currency_description,
        currency_code,
        currency_rate.rate,
        currency_rate.validity_start_date.to_s,
        currency_rate.validity_end_date.to_s,
      ]
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
