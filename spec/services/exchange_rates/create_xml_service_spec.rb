RSpec.describe ExchangeRates::CreateXmlService do
  subject(:create_xml) { described_class.call(data) }

  context 'with valid data' do
    before do
      create(
        :exchange_rate_currency_rate,
        :with_usa,
        validity_start_date: '2020-02-01',
      )
    end

    let(:data) do
      ExchangeRateCurrencyRate.for_month(2, 2020)
    end

    let(:parsed_xml) do
      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <exchangeRateMonthList Period="01/Feb/2020 to 29/Feb/2020">
          <exchangeRate>
            <countryName>United States</countryName>
            <countryCode>US</countryCode>
            <currencyName>Dollar</currencyName>
            <currencyCode>USD</currencyCode>
            <rateNew>4.8012</rateNew>
          </exchangeRate>
        </exchangeRateMonthList>
      XML
    end

    it { expect(create_xml).to eq(parsed_xml) }
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
end
