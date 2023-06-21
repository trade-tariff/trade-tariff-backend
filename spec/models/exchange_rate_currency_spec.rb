require 'csv'

RSpec.describe ExchangeRateCurrency do
  let(:csv_file) { 'spec/fixtures/currency.csv' }
  let(:aed) { described_class.where(currency_code: 'AED').take }
  let(:aud) { described_class.where(currency_code: 'AUD').take }

  before do
    stub_const('ExchangeRateCurrency::CURRENCY_FILE', Rails.root.join('spec/fixtures/currency.csv'))
  end

  describe '.populate' do
    before { described_class.populate }

    it { expect(described_class.count).to eq(2) }

    it { expect(aed.currency_description).to eq('Dirham') }

    it { expect(aed.spot_rate_required).to eq(false) }

    it { expect(aud.currency_description).to eq('Dollar') }

    it { expect(aud.spot_rate_required).to eq(true) }
  end
end
