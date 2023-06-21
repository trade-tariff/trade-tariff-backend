require 'csv'

RSpec.describe ExchangeRateCurrency do
  let(:csv_file) { 'spec/fixtures/currency.csv' }

  before do
    stub_const('ExchangeRateCurrency::CURRENCY_FILE', Rails.root.join('spec/fixtures/currency.csv'))
  end

  describe '.populate' do
    it 'populates ExchangeRateCurrency records from the CSV file' do
      expect(described_class).to receive(:unrestrict_primary_key)

      expect(described_class).to receive(:create).with(
        currency_code: 'AED',
        currency_description: 'Dirham',
        spot_rate_required: false,
      )

      expect(described_class).to receive(:create).with(
        currency_code: 'AUD',
        currency_description: 'Dollar',
        spot_rate_required: true,
      )

      expect(described_class).to receive(:restrict_primary_key)

      described_class.populate
    end
  end
end
