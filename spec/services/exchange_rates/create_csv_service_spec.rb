RSpec.describe ExchangeRates::CreateCsvService do
  subject(:create_csv) { described_class.call(data) }

  context 'with valid data' do
    let(:data) { ExchangeRateCurrencyRate.for_month(2, 2020, 'scheduled') }
    let(:parsed_csv) do
      "Country/Territories,Currency,Currency Code,Currency Units per £1,Start date,End date\nUnited States,Dollar,USD,4.8012,01/02/2020,29/02/2020\n"
    end

    before do
      create(
        :exchange_rate_currency_rate,
        :with_usa,
        validity_start_date: '2020-02-01',
      )
    end

    it { expect(create_csv).to eq(parsed_csv) }
  end

  context 'with invalid data' do
    context 'when data is not an array' do
      let(:data) { '' }

      it 'error generates the csv' do
        expect { create_csv }.to raise_error(ArgumentError)
      end
    end

    context 'when data is an array with invalid data' do
      let(:data) { ['string', 456, build(:exchange_rate_currency)] }

      it 'error generates the csv' do
        expect { create_csv }.to raise_error(ArgumentError)
      end
    end
  end
end
