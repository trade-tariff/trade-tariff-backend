RSpec.describe ExchangeRates::CreateCsvService do
  subject(:create_csv) { described_class.call(data) }

  before do
    setup_data
  end

  context 'with valid data' do
    let(:data) do
      ExchangeRateCurrencyRate.for_month(2, 2020)
    end

    let(:parsed_csv) do
      [
        ['Country/Territories', 'Currency', 'Currency Code', 'Currency Units per £1', 'Start date', 'End date'],
        ['Abu Dhabi', 'Dirham', 'AED', '4.82', '01/02/2020', '29/02/2020'],
        ['Australia', 'Australian Dollar', 'AUD', '1.98', '01/02/2020', '29/02/2020'],
        ['Canada', 'Candian Dollar', 'CAD', '1.894', '01/02/2020', '29/02/2020'],
        ['Dubai', 'Dirham', 'AED', '4.82', '01/02/2020', '29/02/2020'],
        ['Europe', 'Euro', 'EUR', '1.18', '01/02/2020', '29/02/2020'],
        ['United States', 'US Dollar', 'USD', '1.35', '01/02/2020', '29/02/2020'],
      ]
    end

    it 'generates the csv' do
      expect(CSV.parse(create_csv)).to eq(parsed_csv)
    end
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

  def setup_data
    all_currency_rates_file = 'spec/fixtures/exchange_rates/all_rates.csv'
    currency_rate_file = 'spec/fixtures/exchange_rates/currency.csv'
    territory_file = 'spec/fixtures/exchange_rates/territory.csv'

    ExchangeRateCurrencyRate.populate(Rails.root.join(all_currency_rates_file))
    ExchangeRateCurrency.populate(Rails.root.join(currency_rate_file))
    ExchangeRateCountry.populate(Rails.root.join(territory_file))
  end
end
