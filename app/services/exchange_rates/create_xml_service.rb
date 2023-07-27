class ExchangeRates::CreateXmlService
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

    create_xml
  end

private

  def create_xml
    builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
      xml.exchangeRateMonthList('Period' => "#{formatted_start_date} to #{formatted_end_date}") do
        order_data.each do |currency_country_data|
          country_name = currency_country_data[COUNTRY_NAME_INDEX]
          currency_rate = currency_country_data[CURRENCY_RATE_INDEX]

          xml.exchangeRate do
            xml.countryName country_name
            xml.countryCode currency_rate.exchange_rate_countries.find { |country| country.country == country_name }.country_code
            xml.currencyName currency_rate.exchange_rate_currency.try(:currency_description)
            xml.currencyCode currency_rate.currency_code
            xml.rateNew currency_rate.rate
          end
        end
      end
    end

    builder.to_xml
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

  def formatted_start_date
    data.first.validity_start_date.strftime('%d/%b/%Y')
  end

  def formatted_end_date
    data.first.validity_end_date.strftime('%d/%b/%Y')
  end

  def valid_data?
    return false unless data.is_a?(Array)
    return false unless data.all? { |value| value.is_a?(ExchangeRateCurrencyRate) }

    true
  end

  def argument_error
    error_message = 'Argument error, invalid data, exchange rate monthly data'
    Rails.logger.error(error_message)

    raise ArgumentError, error_message
  end
end
