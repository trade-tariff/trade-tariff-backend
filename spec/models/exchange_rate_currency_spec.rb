require 'csv'

RSpec.describe ExchangeRateCurrency do
  let(:csv_file) { 'spec/fixtures/exchange_rates/currency.csv' }
  let(:aed) { described_class.where(currency_code: 'AED').take }
  let(:aud) { described_class.where(currency_code: 'AUD').take }

  before do
    stub_const('ExchangeRateCurrency::CURRENCY_FILE', Rails.root.join(csv_file))
    described_class.populate
  end

  describe '.populate' do
    it { expect(described_class.count).to eq(2) }

    it { expect(aed.currency_description).to eq('Dirham') }

    it { expect(aed.spot_rate_required).to eq(false) }

    it { expect(aud.currency_description).to eq('Dollar') }

    it { expect(aud.spot_rate_required).to eq(true) }
  end
end
