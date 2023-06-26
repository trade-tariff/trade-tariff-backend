require 'csv'

RSpec.describe ExchangeRateCurrencyRate do
  let(:csv_file) { 'spec/fixtures/exchange_rates/all_rates.csv' }
  let(:january) { described_class.where(validity_start_date: '2020-01-01', validity_end_date: '2020-01-31') }
  let(:february) { described_class.where(validity_start_date: '2020-02-01', validity_end_date: '2020-02-29') }
  let(:aed) { january.where(currency_code: 'AED').take }
  let(:scheduled) { described_class.where(rate_type: 'scheduled') }

  before do
    described_class.populate Rails.root.join(csv_file)
  end

  describe '.populate' do
    it { expect(january.count).to eq(2) }

    it { expect(february.count).to eq(1) }

    it { expect(aed.rate).to eq(4.8012) }

    it { expect(scheduled.count).to eq(3) }
  end
end
