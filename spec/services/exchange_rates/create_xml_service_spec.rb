RSpec.describe ExchangeRates::CreateXmlService do
  subject(:create_xml) { described_class.call(data) }

  before do
    setup_data
  end

  context 'with valid data' do
    let(:data) do
      ExchangeRateCurrencyRate.for_month(2, 2020)
    end

    let(:parsed_xml) do
      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <exchangeRateMonthList Period="01/Feb/2020 to 29/Feb/2020">
          <exchangeRate>
            <countryName>Abu Dhabi</countryName>
            <countryCode>DH</countryCode>
            <currencyName>Dirham</currencyName>
            <currencyCode>AED</currencyCode>
            <rateNew>4.82</rateNew>
          </exchangeRate>
          <exchangeRate>
            <countryName>Australia</countryName>
            <countryCode>AU</countryCode>
            <currencyName>Australian Dollar</currencyName>
            <currencyCode>AUD</currencyCode>
            <rateNew>1.98</rateNew>
          </exchangeRate>
          <exchangeRate>
            <countryName>Canada</countryName>
            <countryCode>CA</countryCode>
            <currencyName>Candian Dollar</currencyName>
            <currencyCode>CAD</currencyCode>
            <rateNew>1.894</rateNew>
          </exchangeRate>
          <exchangeRate>
            <countryName>Dubai</countryName>
            <countryCode>DU</countryCode>
            <currencyName>Dirham</currencyName>
            <currencyCode>AED</currencyCode>
            <rateNew>4.82</rateNew>
          </exchangeRate>
          <exchangeRate>
            <countryName>Europe</countryName>
            <countryCode>EU</countryCode>
            <currencyName>Euro</currencyName>
            <currencyCode>EUR</currencyCode>
            <rateNew>1.18</rateNew>
          </exchangeRate>
          <exchangeRate>
            <countryName>United States</countryName>
            <countryCode>US</countryCode>
            <currencyName>US Dollar</currencyName>
            <currencyCode>USD</currencyCode>
            <rateNew>1.35</rateNew>
          </exchangeRate>
        </exchangeRateMonthList>
      XML
    end

    it 'generates the XML' do
      expect(strip_xml_whitespace(create_xml)).to eq(strip_xml_whitespace("#{parsed_xml} \n"))
    end
  end

  context 'with invalid data' do
    context 'when data is not an array' do
      let(:data) { '' }

      it 'raises ArgumentError' do
        expect { create_xml }.to raise_error(ArgumentError)
      end
    end

    context 'when data is an array with invalid data' do
      let(:data) { ['string', 456, build(:exchange_rate_currency)] }

      it 'raises ArgumentError' do
        expect { create_xml }.to raise_error(ArgumentError)
      end
    end
  end

  def setup_data
    all_currency_rates_file = 'spec/fixtures/exchange_rates/all_rates.csv'
    currency_rate_file = 'spec/fixtures/exchange_rates/currency.csv'
    territory_file = 'spec/fixtures/exchange_rates/territory.csv'

    ExchangeRateCurrencyRate.populate(Rails.root.join(all_currency_rates_file))
    ExchangeRateCurrency.populate(Rails.root.join(currency_rate_file))
    ExchangeRateCountry.populate(Rails.root.join(territory_file))
  end

  def strip_xml_whitespace(xml)
    xml.gsub(/>\s+/, '>').gsub(/\s+</, '<').strip
  end
end
