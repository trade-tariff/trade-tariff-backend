RSpec.describe ExchangeRates::CreateCsvHmrcService do
  subject(:create_csv) { described_class.call(data) }

  context 'with valid data' do
    before do
      create(
        :exchange_rate_currency_rate,
        :with_usa,
        rate: 4.82,
        validity_start_date: '2020-02-01',
      )
    end

    let(:data) do
      ExchangeRateCurrencyRate.for_month(2, 2020)
    end

    let(:parsed_csv) do
      [
        ['Period', 'countryName', 'countryCode', 'currencyName', 'currencyCode', 'rateNew'],
        ['01/Feb/2020 to 29/Feb/2020', 'United States', 'US', 'Dollar', 'USD', '4.8200'],
      ]
    end

    it 'generates the csv' do
      expect(CSV.parse(create_csv)).to eq(parsed_csv)
    end
  end

  context 'with invalid data' do
    context 'when data is not an array' do
      let(:data) { '' }

      it 'raises an ArgumentError' do
        expect { create_csv }.to raise_error(ArgumentError)
      end
    end

    context 'when data is an array with invalid data' do
      let(:data) { ['string', 456, build(:exchange_rate_currency)] }

      it 'raises an ArgumentError' do
        expect { create_csv }.to raise_error(ArgumentError)
      end
    end
  end
end