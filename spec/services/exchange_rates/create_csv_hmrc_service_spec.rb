require 'rails_helper'

RSpec.describe ExchangeRates::CreateCsvHmrcService do
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
        ['Period', 'countryName', 'countryCode', 'currencyName', 'currencyCode', 'rateNew'],
        ['01/Feb/2020 to 29/Feb/2020', 'Abu Dhabi', 'DH', 'Dirham', 'AED', '4.8200'],
        ['01/Feb/2020 to 29/Feb/2020', 'Australia', 'AU', 'Australian Dollar', 'AUD', '1.9800'],
        ['01/Feb/2020 to 29/Feb/2020', 'Canada', 'CA', 'Candian Dollar', 'CAD', '1.8940'],
        ['01/Feb/2020 to 29/Feb/2020', 'Dubai', 'DU', 'Dirham', 'AED', '4.8200'],
        ['01/Feb/2020 to 29/Feb/2020', 'Europe', 'EU', 'Euro', 'EUR', '1.1800'],
        ['01/Feb/2020 to 29/Feb/2020', 'United States', 'US', 'US Dollar', 'USD', '1.3500'],
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

  def setup_data
    all_currency_rates_file = 'spec/fixtures/exchange_rates/all_rates.csv'
    currency_rate_file = 'spec/fixtures/exchange_rates/currency.csv'
    territory_file = 'spec/fixtures/exchange_rates/territory.csv'

    ExchangeRateCurrencyRate.populate(Rails.root.join(all_currency_rates_file))
    ExchangeRateCurrency.populate(Rails.root.join(currency_rate_file))
    ExchangeRateCountry.populate(Rails.root.join(territory_file))
  end
end
