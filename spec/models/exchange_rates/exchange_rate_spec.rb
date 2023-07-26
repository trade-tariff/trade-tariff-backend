RSpec.describe ExchangeRates::ExchangeRate do
  describe '#id' do
    let(:exchange_rate) { build(:exchange_rate) }

    before do
      exchange_rate.year = 2023
      exchange_rate.month = 6
    end

    it 'returns the formatted exchange_rate ID' do
      expect(exchange_rate.id).to eq('2023-6-DH')
    end
  end

  describe '.build' do
    let(:rate) { build(:exchange_rate) }
    let(:exchange_rate) { described_class.build(rate) }

    it 'builds a exchange_rate' do
      expect(exchange_rate).to be_a(described_class)
    end

    it 'builds a exchange_rate with correct attributes', :aggregate_failures do
      expect(exchange_rate.country).to eq(rate.country)
      expect(exchange_rate.country_code).to eq(rate.country_code)
      expect(exchange_rate.currency_description).to eq(rate.currency_description)
      expect(exchange_rate.currency_code).to eq(rate.currency_code)
      expect(exchange_rate.rate).to eq(rate.rate)
      expect(exchange_rate.validity_start_date).to eq(rate.validity_start_date)
      expect(exchange_rate.validity_end_date).to eq(rate.validity_end_date)
    end
  end

  describe '.wrap' do
    let(:rates) { build_list(:exchange_rate, 1) }
    let(:exchange_rates) { described_class.wrap(rates) }

    it 'builds an array of exchange_rates' do
      expect(exchange_rates).to be_an(Array)
    end

    it 'builds a exchange_rate with correct attributes', :aggregate_failures do
      exchange_rates.each do |exchange_rate|
        expect(exchange_rate.country).to eq(rates.first.country)
        expect(exchange_rate.country_code).to eq(rates.first.country_code)
        expect(exchange_rate.currency_description).to eq(rates.first.currency_description)
        expect(exchange_rate.currency_code).to eq(rates.first.currency_code)
        expect(exchange_rate.rate).to eq(rates.first.rate)
        expect(exchange_rate.validity_start_date).to eq(rates.first.validity_start_date)
        expect(exchange_rate.validity_end_date).to eq(rates.first.validity_end_date)
      end
    end
  end
end
