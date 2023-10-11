class ExchangeRates::CreateXmlService
  def self.call(data)
    new(data).call
  end

  def initialize(data)
    @data = data
  end

  def call
    builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
      xml.exchangeRateMonthList('Period' => "#{formatted_start_date} to #{formatted_end_date}") do
        @data.each do |rate|
          xml.exchangeRate do
            xml.countryName rate.country_description
            xml.countryCode rate.country_code
            xml.currencyName rate.currency_description
            xml.currencyCode rate.currency_code
            xml.rateNew rate.presented_rate
          end
        end
      end
    end

    builder.to_xml
  end

private

  def formatted_start_date
    @data.first.validity_start_date.strftime('%d/%b/%Y')
  end

  def formatted_end_date
    @data.first.validity_end_date.strftime('%d/%b/%Y')
  end
end
