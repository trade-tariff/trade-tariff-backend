require 'csv'

RSpec.describe ExchangeRateCurrencyRate do
  let(:csv_file) { 'spec/fixtures/exchange_rates/all_rates.csv' }
  let(:january) { described_class.where(validity_start_date: '2020-01-01', validity_end_date: '2020-01-31') }
  let(:february) { described_class.where(validity_start_date: '2020-02-01', validity_end_date: '2020-02-29') }
  let(:aed) { january.where(currency_code: 'AED').take }

  before do
    described_class.populate Rails.root.join(csv_file)
  end

  describe '.populate' do
    it { expect(january.count).to eq(2) }

    it { expect(february.count).to eq(1) }

    it { expect(aed.rate).to eq(4.8012) }

    context 'when scheduled rates start and end in same month' do
      let(:scheduled) { described_class.where(rate_type: 'scheduled') }

      it { expect(scheduled.count).to eq(3) }

      it { expect(scheduled.first.validity_end_date).not_to be_nil }

      it { expect(scheduled.first.validity_start_date).not_to be_nil }
    end

    context 'when spot rates start on last day of March or December' do
      let(:spot) { described_class.where(rate_type: 'spot') }

      it { expect(spot.count).to eq(4) }

      it { expect(spot.first.validity_end_date).to be_nil }

      it { expect(spot.first.validity_start_date).not_to be_nil }
    end
  end
end
