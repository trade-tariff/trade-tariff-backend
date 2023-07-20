class ExchangeRates::CreateXmlService
  attr_reader :data

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
        data.each do |currency_rate|
          xml.exchangeRate do
            xml.countryName currency_rate.country.country if currency_rate.country
            xml.countryCode currency_rate.country&.country_code if currency_rate.country
            xml.currencyName currency_rate.currency.currency_description if currency_rate.currency
            xml.currencyCode currency_rate.currency_code
            xml.rateNew currency_rate.rate
          end
        end
      end
    end

    builder.to_xml
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
