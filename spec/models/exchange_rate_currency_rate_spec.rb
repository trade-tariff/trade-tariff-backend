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
  end

  describe '.all_years' do
    it 'returns the distinct years in descending order' do
      expect(described_class.all_years).to eq([2023, 2020])
    end
  end

  describe '.max_year' do
    it 'returns the maximum year from the validity start dates' do
      expect(described_class.max_year).to eq(2023)
    end
  end

  describe '.months_for_year' do
    it 'returns the distinct months for the given year in descending order' do
      expect(described_class.months_for_year(2020)).to eq([2, 1])
    end
  end

  describe '#scheduled_rate?' do
    subject(:currency_rate) { build(:exchange_rate_currency_rate) }

    it { is_expected.to be_scheduled_rate }

    context 'when validity_end_date is nil' do
      before { currency_rate.validity_end_date = nil }

      it { is_expected.not_to be_scheduled_rate }
    end

    context 'when validity_start_date is not the first day of the month' do
      before { currency_rate.validity_start_date = Date.new(2020, 1, 15) }

      it { is_expected.not_to be_scheduled_rate }
    end

    context 'when validity_end_date is not the last day of the month' do
      before { currency_rate.validity_end_date = Date.new(2020, 1, 15) }

      it { is_expected.not_to be_scheduled_rate }
    end
  end

  describe '#spot_rate?' do
    subject(:currency_rate) { build(:exchange_rate_currency_rate, :spot_rate) }

    it { is_expected.to be_spot_rate }

    context 'when validity_end_date is present' do
      before { currency_rate.validity_end_date = Date.new(2022, 12, 31) }

      it { is_expected.not_to be_spot_rate }
    end

    context 'when validity_start_date is not the last day of the month' do
      before { currency_rate.validity_start_date = Date.new(2022, 12, 15) }

      it { is_expected.not_to be_spot_rate }
    end

    context 'when rate_type is not "spot"' do
      subject(:currency_rate) { build(:exchange_rate_currency_rate) }

      it { is_expected.not_to be_spot_rate }
    end
  end

  describe '.scheduled' do
    it 'returns only the rates with rate_type "scheduled"' do
      expect(described_class.scheduled).to all(be_scheduled_rate)
    end
  end

  describe '.spot' do
    it 'returns only the rates with rate_type "spot"' do
      expect(described_class.spot).to all(be_spot_rate)
    end
  end

  describe '.by_year' do
    it 'returns the rates for the specified year' do
      expect(described_class.by_year(2023).count).to eq(2)
    end

    it 'returns nil if year is blank' do
      expect(described_class.by_year(nil)).to be_nil
    end
  end
end
