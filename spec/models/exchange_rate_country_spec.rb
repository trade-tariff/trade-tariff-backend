require 'csv'

RSpec.describe ExchangeRateCountry do
  let(:csv_file) { 'spec/fixtures/exchange_rates/territory.csv' }
  let(:dh) { described_class.where(country_code: 'DH').take }
  let(:kn) { described_class.where(country_code: 'KN').take }
  let(:lc) { described_class.where(country_code: 'LC').take }

  before do
    described_class.populate Rails.root.join(csv_file)
  end

  describe '.populate' do
    it 'saves countrys with duplicate currency codes' do
      expect(described_class.count).to eq(8)
    end

    it { expect(dh.country).to eq('Abu Dhabi') }

    it { expect(dh.currency_code).to eq('AED') }

    it { expect(kn.country).to eq('Saint Kitts and Nevis') }

    it { expect(kn.currency_code).to eq('XCD') }

    it { expect(lc.country).to eq('Saint Lucia') }

    it { expect(lc.currency_code).to eq('XCD') }
  end
end
