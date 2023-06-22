require 'csv'

RSpec.describe ExchangeRateCurrencyRate do
  let(:csv_file) { 'spec/fixtures/exchange_rates/all_rates.csv' }
  let(:january) { described_class.where(validity_start_date: '2020-01-01', validity_end_date: '2020-01-31') }
  let(:february) { described_class.where(validity_start_date: '2020-02-01', validity_end_date: '2020-02-29') }
  let(:aed) { january.where(currency_code: 'AED').take }

  before do
    stub_const('ExchangeRateCurrencyRate::RATES_FILE', Rails.root.join('spec/fixtures/exchange_rates/all_rates.csv'))
    described_class.populate
  end

  describe '.populate' do
    it { expect(january.count).to eq(2) }

    it { expect(february.count).to eq(1) }

    it { expect(aed.rate).to eq(4.8012) }
  end
end
