RSpec.describe ExchangeRates::CreateXmlService do
  subject(:create_xml) { described_class.call(data) }

  before do
    create(
      :exchange_rate_currency_rate,
      :with_usa,
      validity_start_date: '2020-02-01',
    )
  end

  let(:data) do
    ExchangeRateCurrencyRate.for_month(2, 2020, 'scheduled')
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
